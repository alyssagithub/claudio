import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { forkSession, query } from "@anthropic-ai/claude-agent-sdk";
import type { AgentDefinition, EffortLevel, PermissionMode, SDKUserMessage } from "@anthropic-ai/claude-agent-sdk";
import { AllowedTools, AutoBias, AutoTier, PermissionModeFor, CancelGraceMilliseconds, CoalesceMilliseconds, DefaultMode, SubagentModels, Subagents, EffortOrder, LeanMode, PlanInstructions, CommandsCacheFile, DesktopConfigPath, FinishedTurnLifetimeMilliseconds, IdleSessionMilliseconds, KeepSessionsWarm, MaxWarmSessions, MostCallText, SystemPromptFor, WorkingDirectory } from "./Config.js";
import { AddDesktopSession, ExtractContext, GetConversation, RecordCost, RememberOwnSession, StripContext, UpdateDesktopSession } from "./Conversations.js";
import { DecodeImage, ImagesInContent } from "./Images.js";
import { CapToolOutput } from "./ResultCap.js";
import { AskServerFor, AskServerName } from "./Ask.js";
import type { Reacher, ReacherIn } from "./Tools.js";
import { Request as RequestStudio } from "./Studio.js";
import { ReadPluginSetting } from "./PluginSettings.js";
import { MirrorSkills, MirrorSyncedSkills } from "./SyncedSkills.js";
import { CountLines, EditedFile, ReadFileText } from "./Lines.js";
import { ChooseModel, GetModels, NextEffort, RecordTurnOutcome, RememberModels, SupportsEffort } from "./Models.js";
import type { Asked, Breakdown, Call, CallStatus, ContentBlock, Content, JobAnswer, LineCount, Part, Permission, Picture, Question, Query, SdkMessage, SentImage, Session, Task, Turn, TurnRequest, Usage } from "./Types.js";

const Turns = new Map<string, Turn>();
const Sessions = new Map<string, Session>();
const SessionAllowances = new Map<string, Set<string>>();
const AllowedServers = AllowedTools
  .filter((Name) => Name.startsWith("mcp__"))
  .map((Name) => Name.split("__")[1]);

function ReadCommandsCache() {
  try {
    return {
      ...JSON.parse(fs.readFileSync(CommandsCacheFile, "utf8")),
      ready: true,
    };
  } catch {
    return {
      slashCommands: [],
      skills: [],
      ready: false,
    };
  }
}

let Commands = ReadCommandsCache();
let AskedForModels = false;
let Limits = new Map<string, unknown>();

export function GetLimits() {
  return [...Limits.values()];
}

function Blocks(Message: SdkMessage): ContentBlock[] {
  const Content = Message.message && Message.message.content;

  return Array.isArray(Content) ? Content : [];
}

function StoreWindow(Into: Map<string, unknown>, Kind: string, Label: string, Entry: {utilization?: number, resets_at?: string} | undefined) {
  if (!Entry) {
    return;
  }

  Into.set(Kind, {
    kind: Kind,
    label: Label,
    status: "allowed",
    utilization: typeof Entry.utilization === "number" ? Entry.utilization / 100 : null,
    resetsAt: Entry.resets_at ? Math.floor(Date.parse(Entry.resets_at) / 1000) : null,
  });
}

export function GetBreakdown(ConversationId: string | null): Breakdown | null {
  const Session = ConversationId ? Sessions.get(ConversationId) : null;

  return (Session && Session.Breakdown) || null;
}

function Rank(Entry: {deferred: boolean, name: string}) {
  if (Entry.deferred) {
    return 3;
  }

  return /free space/i.test(Entry.name) ? 2 : 1;
}

export async function RefreshContext(Session: Session) {
  if (!Session.Query || !Session.Query.getContextUsage) {
    return;
  }

  try {
    const Usage = await Session.Query.getContextUsage();

    if (!Usage || !Array.isArray(Usage.categories)) {
      return;
    }

    Session.Breakdown = {
      total: Usage.totalTokens || 0,
      max: Usage.maxTokens || 0,
      percentage: Usage.percentage || 0,
      model: Usage.model || null,
      categories: Usage.categories
        .map((Entry: any) => ({
          name: Entry.name,
          tokens: Entry.tokens || 0,
          colour: String(Entry.color || ""),
          deferred: Entry.isDeferred === true,
        }))
        .sort((Left: {deferred: boolean, name: string, tokens: number}, Right: {deferred: boolean, name: string, tokens: number}) => Rank(Left) - Rank(Right) || Right.tokens - Left.tokens),
    };
  } catch (Error) {
    console.error("Could not read context usage: " + (Error as Error).message);
  }
}

export async function PollUsage(ConversationId: string | null) {
  const Ready = [...Sessions.values()].find((Entry) => Entry.Query);

  if (!Ready) {
    return false;
  }

  await RefreshUsage(Ready);

  const Used = ConversationId ? Sessions.get(ConversationId) : null;

  if (Used && Used.Query && Used.HasSpoken) {
    await RefreshContext(Used);
  }

  return true;
}

export async function RefreshUsage(Session: Session) {
  const Ask = Session.Query && Session.Query.usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET;

  if (!Ask) {
    return;
  }

  try {
    const Usage = await Ask.call(Session.Query);
    const Windows = (Usage && Usage.rate_limits) as Record<string, any> | undefined;

    if (!Windows) {
      return;
    }

    const Fresh = new Map();

    StoreWindow(Fresh, "five_hour", "5-hour limit", Windows.five_hour);
    StoreWindow(Fresh, "seven_day", "Weekly across all models", Windows.seven_day);
    StoreWindow(Fresh, "seven_day_opus", "Weekly on Opus", Windows.seven_day_opus);
    StoreWindow(Fresh, "seven_day_sonnet", "Weekly on Sonnet", Windows.seven_day_sonnet);

    for (const Scoped of Windows.model_scoped || []) {
      StoreWindow(Fresh, "model:" + Scoped.display_name, "Weekly on " + Scoped.display_name, Scoped);
    }

    Limits = Fresh;
  } catch (Error) {
    console.error("Could not read usage: " + (Error as Error).message);
  }
}

export function ReadMcpServers() {
  try {
    const Desktop = JSON.parse(fs.readFileSync(DesktopConfigPath, "utf8")) as {mcpServers?: unknown};
    const Servers: Record<string, {command: string, args: string[], env?: Record<string, string>}> = {};

    for (const [Name, Definition] of Object.entries((Desktop.mcpServers || {}) as Record<string, {command?: string, args?: string[], env?: Record<string, string>}>)) {
      if (!Definition.command || !AllowedServers.includes(Name)) {
        continue;
      }

      Servers[Name] = {
        command: Definition.command,
        args: Definition.args || [],
        env: Definition.env,
      };
    }

    return Servers;
  } catch (Error) {
    console.error(`Could not read MCP servers from ${DesktopConfigPath}: ${(Error as Error).message}`);
    return {};
  }
}

const Destructive = /destroy|:remove\(|clearallchildren/i;

function IsRisky(ToolName: string, Input: unknown) {
  const Name = ToolName.replace(/^mcp__.*?__/, "");
  const Body = JSON.stringify(Input || {});

  if (Name === "set_script_source" || Name === "delete_script_lines" || Name === "Write") {
    return true;
  }

  if (Name === "manage_instance" && /"action"\s*:\s*"(delete|destroy|remove)"/i.test(Body)) {
    return true;
  }

  return (Name === "execute_luau" || Name === "run_as_job" || Name === "Bash" || Name === "PowerShell") && Destructive.test(Body);
}

function IsAllowedTool(ToolName: string) {
  return AllowedTools.some((Pattern) => Pattern.endsWith("*") ? ToolName.startsWith(Pattern.slice(0, -1)) : ToolName === Pattern);
}

const ServerStatuses: Record<string, string> = {};

export function GetMcpServers() {
  const Configured = ReadMcpServers();

  return Object.entries(Configured).map(([Name, Definition]) => ({
    name: Name,
    command: Definition.command,
    arguments: (Definition.args || []).join(" "),
    status: ServerStatuses[Name] || "unknown",
  }));
}

function RememberServers(Init: {mcp_servers?: {name: string, status: string}[]}) {
  for (const Server of Init.mcp_servers || []) {
    ServerStatuses[Server.name] = Server.status;
  }
}

function ReadDescription(File: string): string {
  try {
    const Lines = fs.readFileSync(File, "utf8").slice(0, 4000).split(NewLine);

    if (Lines[0].trim() !== "---") {
      return "";
    }

    for (const Line of Lines.slice(1)) {
      if (Line.trim() === "---") {
        return "";
      }

      if (Line.startsWith("description:")) {
        return Line.slice(12).trim().replace(/^["']|["']$/g, "").slice(0, 200);
      }
    }

    return "";
  } catch {
    return "";
  }
}

function ReadFolder(Folder: string): string[] {
  try {
    return fs.readdirSync(Folder);
  } catch {
    return [];
  }
}

function PluginFolders() {
  const Root = path.join(os.homedir(), ".claude", "plugins", "marketplaces");
  const Folders = [];

  for (const Marketplace of ReadFolder(Root)) {
    for (const Group of ["plugins", "external_plugins"]) {
      const Parent = path.join(Root, Marketplace, Group);

      for (const Plugin of ReadFolder(Parent)) {
        Folders.push(path.join(Parent, Plugin));
      }
    }
  }

  return Folders;
}

function ReadDescriptions(): Record<string, string | undefined> {
  const Found: Record<string, string | undefined> = {};
  const SkillsRoot = path.join(os.homedir(), ".claude", "skills");

  for (const Root of [MirrorSkills, ProjectFolder ? path.join(ProjectFolder, ".claude", "skills") : null]) {
    for (const Name of Root ? ReadFolder(Root) : []) {
      Found[Name] = ReadDescription(path.join(Root as string, Name, "SKILL.md"));
    }
  }

  const CommandsRoot = path.join(os.homedir(), ".claude", "commands");

  try {
    for (const Name of fs.readdirSync(SkillsRoot)) {
      Found[Name] = ReadDescription(path.join(SkillsRoot, Name, "SKILL.md"));
    }
  } catch {
    Found.skills = undefined;
  }

  try {
    for (const Name of fs.readdirSync(CommandsRoot)) {
      if (Name.endsWith(".md")) {
        Found[Name.slice(0, -3)] = ReadDescription(path.join(CommandsRoot, Name));
      }
    }
  } catch {
    Found.commands = undefined;
  }

  for (const Folder of PluginFolders()) {
    for (const Name of ReadFolder(path.join(Folder, "skills"))) {
      Found[Name] = Found[Name] || ReadDescription(path.join(Folder, "skills", Name, "SKILL.md"));
    }

    for (const Name of ReadFolder(path.join(Folder, "commands"))) {
      if (Name.endsWith(".md")) {
        Found[Name.slice(0, -3)] = Found[Name.slice(0, -3)] || ReadDescription(path.join(Folder, "commands", Name));
      }
    }
  }

  return Found;
}

let ProjectFolder: string | null = null;

function RememberCommands(Init: {slash_commands?: string[], skills?: string[], cwd?: string}) {
  ProjectFolder = typeof Init.cwd === "string" ? Init.cwd : ProjectFolder;
  Described = null;
  Commands = {
    slashCommands: Init.slash_commands || [],
    skills: Init.skills || [],
    ready: true,
  };

  try {
    fs.mkdirSync(path.dirname(CommandsCacheFile), {recursive: true});
    fs.writeFileSync(CommandsCacheFile, JSON.stringify({
      slashCommands: Commands.slashCommands,
      skills: Commands.skills,
    }));
  } catch {
    return;
  }
}

let Described: Record<string, string | undefined> | null = null;
let DescribedAt = 0;

function ProjectCommands(Folder: string): Map<string, string> {
  const Found = new Map<string, string>();
  const Skills = path.join(Folder, ".claude", "skills");
  const Written = path.join(Folder, ".claude", "commands");

  for (const Name of ReadFolder(Skills)) {
    if (fs.existsSync(path.join(Skills, Name, "SKILL.md"))) {
      Found.set(Name, ReadDescription(path.join(Skills, Name, "SKILL.md")));
    }
  }

  for (const Name of ReadFolder(Written)) {
    if (Name.endsWith(".md")) {
      Found.set(Name.slice(0, -3), ReadDescription(path.join(Written, Name)));
    }
  }

  return Found;
}

export function GetCommands(Folder?: string | null) {
  if (!Described || Date.now() - DescribedAt > 60000) {
    Described = ReadDescriptions();
    DescribedAt = Date.now();
  }

  const Project = Folder && path.isAbsolute(Folder) ? ProjectCommands(Folder) : new Map<string, string>();
  const Names = [...new Set([...Commands.slashCommands, ...Project.keys()])];

  return {
    ...Commands,
    slashCommands: Names,
    commands: Names.map((Name: string) => ({
      name: Name,
      description: Project.get(Name) || (Described || {})[Name] || "",
    })),
  };
}

export async function DiscoverCommands(Folder?: string | null) {
  try {
    for await (const Message of query({
      prompt: "Reply with the single word ready.",
      options: {
        cwd: Folder || WorkingDirectory,
        additionalDirectories: [MirrorSyncedSkills()],
        model: "claude-haiku-4-5",
        maxTurns: 1,
        allowedTools: [],
        mcpServers: {},
        permissionMode: "dontAsk",
        persistSession: false,
      },
    })) {
      if (Message.type === "system" && Message.subtype === "init") {
        RememberCommands(Message);
        RememberServers(Message);

        return;
      }
    }
  } catch (Error) {
    console.error(`Could not discover commands: ${(Error as Error).message}`);
  }
}

const NewLine = "\n";

function TextOf(Content: Content | undefined): string {
  if (typeof Content === "string") {
    return Content;
  }

  return ((Content || []) as ContentBlock[]).filter((Block) => Block.type === "text").map((Block) => Block.text).join("");
}

function TaskNotice(Text: string): Call | null {
  const Status = Text.match(/<status>(\w+)<\/status>/);
  const Summary = Text.match(/<summary>([\s\S]*?)<\/summary>/);

  if (!Text.includes("<task-notification>") || !Status || !Summary) {
    return null;
  }

  return {
    Id: `task-${Date.now()}-${Turns.size}`,
    Name: "TaskNotification",
    Input: `status: ${Status[1]}\nsummary: ${Summary[1].trim()}`,
    Output: "",
    Status: Status[1] === "failed" ? "error" : "done",
    StartedAt: Date.now(),
    Milliseconds: 0,
    Subagent: null,
  };
}

function Describe(Value: unknown): string {
  if (typeof Value === "string") {
    return Value.slice(0, MostCallText);
  }

  if (Array.isArray(Value)) {
    return Value.filter((Block) => !(Block && Block.type === "image")).map((Block) => (Block && Block.type === "text" ? Block.text : JSON.stringify(Block))).join(NewLine).slice(0, MostCallText);
  }

  try {
    return JSON.stringify(Value, null, 2).slice(0, MostCallText);
  } catch {
    return String(Value).slice(0, MostCallText);
  }
}

function AgentsOn(Model: string) {
  const Named: Record<string, unknown> = {};

  for (const [Name, Agent] of Object.entries(Subagents)) {
    Named[Name] = {
      ...Agent,
      model: Model,
    };
  }

  return Named;
}

function SubagentFor(Block: ContentBlock, Model: string) {
  if (Block.name !== "Agent" && Block.name !== "Task") {
    return null;
  }

  const Asked = (Block.input || {}) as {subagent_type?: string, description?: string, prompt?: string};

  if (!Asked.subagent_type || !Subagents[Asked.subagent_type as keyof typeof Subagents]) {
    return null;
  }

  return {
    name: Asked.subagent_type,
    model: Model,
  };
}

function DescribeInput(Input: unknown): string {
  if (!Input || typeof Input !== "object" || Array.isArray(Input)) {
    return Describe(Input);
  }

  return Object.entries(Input)
    .map(([Name, Value]) => `${Name}: ${typeof Value === "string" ? Value : JSON.stringify(Value)}`)
    .join(NewLine)
    .slice(0, MostCallText);
}

function CountUsage(Existing: Usage, Usage: {input_tokens?: number, output_tokens?: number, cache_read_input_tokens?: number}): Usage {
  return {
    Input: Existing.Input + (Usage.input_tokens || 0),
    Output: Existing.Output + (Usage.output_tokens || 0),
    Cached: Existing.Cached + (Usage.cache_read_input_tokens || 0),
  };
}

function Publish(Turn: Turn, Changes: Partial<Turn>) {
  Object.assign(Turn, Changes);
  Turn.Version += 1;

  for (const Resolve of Turn.Waiters.splice(0)) {
    Resolve();
  }
}

function JoinText(Existing: string, Added: string): string {
  if (Existing === "" || Added === "") {
    return Existing + Added;
  }

  return `${Existing}\n\n${Added}`;
}

function JobLimit(Kind: string, Timeout?: number): number | undefined {
  if (typeof Timeout === "number" && Number.isFinite(Timeout) && Timeout > 0) {
    return Math.min(Math.max(Timeout, 1), 1800) * 1000;
  }

  return Kind === "execute" ? 300000 : undefined;
}

function TakeLines(Session: Session, Id: string) {
  const Lines = Session.LineCounts.get(Id) || null;

  Session.LineCounts.delete(Id);
  Session.FilesBefore.delete(Id);

  return Lines;
}

function FinishTurn(Turn: Turn, Status: string, Error?: string | null) {
  if (Turn.Status !== "running" && Turn.Status !== "cancelling") {
    return;
  }

  const Text = JoinText(Turn.CommittedText, Turn.PendingText);

  if (Turn.Question) {
    const Unanswered = Turn.Question;

    Turn.Question = null;
    Unanswered.Resolve(null);
  }

  if (Turn.FallenFrom && Turn.Session && Turn.Session.Query) {
    Turn.Session.Model = Turn.FallenFrom;
    Turn.Session.Query.setModel(Turn.FallenFrom).catch(() => {});
    Turn.Model = Turn.FallenFrom;
    Turn.FallenFrom = null;
  }

  if (Turn.ConversationId) {
    Ended.set(Turn.ConversationId, Date.now());
    UpdateDesktopSession(Turn.ConversationId, (Session) => {
      Session.lastActivityAt = Date.now();
      Session.completedTurns = ((Session.completedTurns as number) || 0) + 1;
    });
  }

  for (const Permission of Turn.Permissions.splice(0)) {
    Permission.Resolve({
      behavior: "deny",
      message: "The turn ended before the user answered.",
    });
  }

  RecordTurnOutcome(Turn.ConversationId || "", {
    Failed: Status === "error",
    Denied: Turn.Activity.some((Name: string) => Name.startsWith("denied ")),
  });
  if (Turn.Session && Turn.Session.CurrentTurn === Turn) {
    Turn.Session.CurrentTurn = null;
  }

  Publish(Turn, {
    Status,
    Error: Error || null,
    CommittedText: Text,
    PendingText: "",
  });
  setTimeout(() => Turns.delete(Turn.Id), FinishedTurnLifetimeMilliseconds);
}

export function AddToTurn(RequestId: string | null, ConversationId: string | null, Text: string, Images: Picture[]): Turn | null {
  for (const Turn of Turns.values()) {
    const Matches = RequestId ? Turn.Id === RequestId : Turn.ConversationId === ConversationId;

    if (!Matches || Turn.Status !== "running" || !Turn.Session) {
      continue;
    }

    Turn.Session.Send(UserMessage(Text, Images));
    Publish(Turn, {
      Parts: Turn.Parts.concat(
        Turn.PendingThinking.trim() !== "" ? [{
          kind: "thinking",
          text: Turn.PendingThinking,
        }] : [],
        Turn.PendingText.trim() !== "" ? [{
          kind: "text",
          text: Turn.PendingText,
        }] : [],
        [{
          kind: "user",
          text: StripContext(Text),
        }],
      ),
      CommittedThinking: JoinText(Turn.CommittedThinking, Turn.PendingThinking),
      CommittedText: JoinText(Turn.CommittedText, Turn.PendingText),
      PendingThinking: "",
      PendingText: "",
    });

    return Turn;
  }

  return null;
}

const Ended = new Map<string, number>();

export function LastEndedAt(ConversationId: string): number {
  return Ended.get(ConversationId) || 0;
}

export function ActiveTurnFor(ConversationId: string): Turn | null {
  for (const Turn of Turns.values()) {
    if (Turn.ConversationId === ConversationId && (Turn.Status === "running" || Turn.Status === "cancelling")) {
      return Turn;
    }
  }

  return null;
}

export function IsConversationBusy(ConversationId: string | null) {
  for (const Turn of Turns.values()) {
    if (Turn.ConversationId === ConversationId && (Turn.Status === "running" || Turn.Status === "cancelling")) {
      return true;
    }
  }

  return false;
}

function AllowanceKey(Turn: Turn) {
  return Turn.Session && Turn.Session.ConversationId ? Turn.Session.Key : Turn.Id;
}

function AskPermission(Turn: Turn, ToolName: string, Input: unknown, Options: {suggestions?: unknown, signal?: AbortSignal}) {
  const Allowed = SessionAllowances.get(AllowanceKey(Turn));

  if (Allowed && Allowed.has(ToolName)) {
    return Promise.resolve({
      behavior: "allow",
      updatedInput: Input,
    });
  }

  return new Promise((Resolve) => {
    const Permission = {
      Id: `${Turn.Id}-${Turn.PermissionCount += 1}`,
      ToolName,
      Input,
      Resolve,
    };

    Turn.Permissions.push(Permission);
    Publish(Turn, {});

    if (Options && Options.signal) {
      Options.signal.addEventListener("abort", () => {
        const Index = Turn.Permissions.indexOf(Permission);

        if (Index === -1) {
          return;
        }

        Turn.Permissions.splice(Index, 1);
        Publish(Turn, {});
        Resolve({
          behavior: "deny",
          message: "Cancelled.",
        });
      }, {once: true});
    }
  });
}

function AskQuestion(Session: Session, Questions: Question[]) {
  return new Promise((Resolve) => {
    const Turn = Session.CurrentTurn;

    if (!Turn) {
      Resolve(null);
      return;
    }

    if (Turn.Question) {
      Turn.Question.Resolve(null);
    }

    Turn.Question = {
      Id: `${Turn.Id}-ask-${Turn.PermissionCount += 1}`,
      Questions,
      Resolve,
    };

    Publish(Turn, {});
  });
}

export function AnswerQuestion(Turn: Turn, QuestionId: string, Answers: unknown) {
  const Asked = Turn.Question;

  if (!Asked || Asked.Id !== QuestionId) {
    return false;
  }

  Turn.Question = null;
  Publish(Turn, {});
  Asked.Resolve(Answers);

  return true;
}

export function AnswerPermission(Turn: Turn, PermissionId: string, Allow: boolean, Always: boolean) {
  const Index = Turn.Permissions.findIndex((Entry) => Entry.Id === PermissionId);

  if (Index === -1) {
    return false;
  }

  const Permission = Turn.Permissions.splice(Index, 1)[0];

  if (Allow && Always) {
    const Key = AllowanceKey(Turn);

    if (!SessionAllowances.has(Key)) {
      SessionAllowances.set(Key, new Set());
    }

    (SessionAllowances.get(Key) as Set<string>).add(Permission.ToolName);
  }

  Publish(Turn, {});
  Permission.Resolve(Allow
    ? {
      behavior: "allow",
      updatedInput: Permission.Input,
    }
    : {
      behavior: "deny",
      message: "The user declined this tool use in Claudio.",
    });
  return true;
}

function UserMessage(Text: string, Images: Picture[]) {
  const Pictures = (Images || []).map((Image: Picture) => ({
    type: "image",
    source: {
      type: "base64",
      media_type: Image.mediaType,
      data: Image.data,
    },
  }));

  return {
    type: "user",
    message: {
      role: "user",
      content: (Pictures as unknown[]).concat([{
        type: "text",
        text: Text,
      }]),
    },
    parent_tool_use_id: null,
  };
}

function CloseIdleSessions() {
  const Warm = [...Sessions.values()].filter((Session) => !Session.CurrentTurn);

  for (const Session of Warm) {
    if (Date.now() - Session.LastUsedAt > IdleSessionMilliseconds) {
      Session.Close();
    }
  }

  const Remaining = [...Sessions.values()].filter((Session) => !Session.CurrentTurn).sort((Left, Right) => Left.LastUsedAt - Right.LastUsedAt);

  for (const Session of Remaining.slice(0, Math.max(0, Remaining.length - MaxWarmSessions))) {
    Session.Close();
  }
}

function CleanOutput(Name: string, Text: string): string {
  if (Name !== "Agent" && Name !== "Task") {
    return Text;
  }

  if (!/agentId|launched successfully/i.test(Text)) {
    return Text;
  }

  return "Ran in the background. Its steps are listed above and its report is in the reply.";
}

function RecordStep(Turn: Turn, Message: SdkMessage & {parent_tool_use_id?: string | null, task_id?: string}) {
  const Call = Turn.Calls.find((Entry) => Entry.Id === Message.parent_tool_use_id);

  if (!Call || Message.type !== "assistant") {
    return;
  }

  const Lines = [];

  for (const Block of Blocks(Message)) {
    if (Block.type === "tool_use") {
      Lines.push(`Used ${Block.name}`);
    }

    if (Block.type === "text" && (Block.text || "").trim() !== "") {
      Lines.push((Block.text || "").trim().replace(/\s+/g, " ").slice(0, 200));
    }
  }

  if (Lines.length === 0) {
    return;
  }

  Call.Steps = (Call.Steps || []).concat(Lines).slice(-40);
  Publish(Turn, {Calls: Turn.Calls.slice()});
}

function RouteMessage(Session: Session, Message: any) {
  const Turn = Session.CurrentTurn;

  if (Message.type === "system" && Message.subtype === "init") {
    RememberCommands(Message);
    RememberServers(Message);

    if (Turn && Turn.OpenedAt) {
      console.log(`Turn ${Turn.Id}: session ready ${Date.now() - Turn.OpenedAt}ms after the turn started, ${Turn.Cold ? "cold" : "reused"}, ${Message.output_style || "default"} style, ${(Message.mcp_servers || []).map((Server: {name: string, status: string}) => `${Server.name} ${Server.status}`).join(", ")}`);
    }
  }

  if (Turn && Message.type === "system" && Message.subtype === "model_refusal_fallback" && Message.scope !== "local") {
    const Original = String(Message.original_model || Turn.Model);
    const Fallback = String(Message.fallback_model || "");

    Session.Model = Fallback;
    Publish(Turn, {
      FallenFrom: Turn.FallenFrom || Original,
      Model: Fallback,
      Activity: Turn.Activity.concat([`stepped down to ${Fallback} after a safety refusal${Message.api_refusal_category ? ` (${Message.api_refusal_category})` : ""}`]),
    });
    console.log(`Turn ${Turn.Id}: ${Original} refused${Message.api_refusal_category ? ` (${Message.api_refusal_category})` : ""}, continuing on ${Fallback}`);

    setTimeout(() => {
      if (Turn.Status !== "running" || !Turn.FallenFrom || Session.Query === null || Session.CurrentTurn !== Turn) {
        return;
      }

      const Back = Turn.FallenFrom;

      Session.Model = Back;
      Session.Query.setModel(Back).catch(() => {});
      Publish(Turn, {
        FallenFrom: null,
        Model: Back,
        Activity: Turn.Activity.concat([`back on ${Back}`]),
      });
      console.log(`Turn ${Turn.Id}: back on ${Back}`);
    }, 45000);

    return;
  }

  if (Turn && Message.type === "system" && Message.subtype === "model_refusal_no_fallback") {
    Publish(Turn, {Activity: Turn.Activity.concat([`refused by ${Message.original_model || Turn.Model}${Message.api_refusal_category ? ` (${Message.api_refusal_category})` : ""}`])});

    return;
  }

  if (Turn && Message.type === "system" && Message.subtype === "status") {
    Turn.Compacting = Message.status === "compacting";

    if (Message.compact_error) {
      console.error(`Turn ${Turn.Id}: compacting failed, ${Message.compact_error}`);
    }

    Publish(Turn, {});

    return;
  }

  if (Turn && Message.type === "system" && Message.subtype === "task_started") {
    Publish(Turn, {
      Tasks: Turn.Tasks.concat([{
        Id: Message.task_id,
        Description: Message.description || "Working",
        Kind: Message.subagent_type || "task",
        Status: "running",
        Background: Message.is_backgrounded === true,
        Depth: Message.spawn_depth || 1,
      }]),
    });

    return;
  }

  if (Turn && Message.type === "system" && Message.subtype === "task_updated") {
    Publish(Turn, {
      Tasks: Turn.Tasks.map((Task) => Task.Id === Message.task_id
        ? {
          ...Task,
          Status: (Message.patch && Message.patch.status) || Task.Status,
          Description: (Message.patch && Message.patch.description) || Task.Description,
          Background: Message.patch && Message.patch.is_backgrounded !== undefined ? Message.patch.is_backgrounded : Task.Background,
          Error: (Message.patch && Message.patch.error) || Task.Error,
        }
        : Task),
    });

    return;
  }

  if (!Turn) {
    return;
  }

  if (Message.parent_tool_use_id) {
    RecordStep(Turn, Message);
    return;
  }

  if (Message.type === "system" && Message.subtype === "init") {
    if (!AskedForModels) {
      AskedForModels = true;
      (Session.Query as Query).supportedModels().then(RememberModels).catch(() => {});
    }

    if (!Session.ConversationId) {
      const Clash = Sessions.get(Message.session_id);

      if (Clash && Clash !== Session) {
        Clash.Close();
      }

      Session.ConversationId = Message.session_id;
      Sessions.delete(Session.Key);
      Session.Key = Message.session_id;
      Sessions.set(Session.Key, Session);
      SessionAllowances.set(Session.Key, SessionAllowances.get(Turn.Id) || new Set());
      SessionAllowances.delete(Turn.Id);
      RememberOwnSession(Message.session_id);
      AddDesktopSession(Message.session_id, Session.WorkingDirectory, StripContext(Turn.Prompt).replace(/\s+/g, " ").trim().slice(0, 60));
    }

    Publish(Turn, {
      SessionId: Message.session_id,
      ConversationId: Message.session_id,
    });
    return;
  }

  if (Message.type === "stream_event") {
    const Event = Message.event;

    if (!Event || !Event.delta) {
      return;
    }

    if (Event.type === "content_block_delta" && Event.delta.type === "text_delta") {
      if (Turn.OpenedAt && !Turn.FirstTextAt) {
        Turn.FirstTextAt = Date.now();
        console.log(`Turn ${Turn.Id}: first reply text ${Turn.FirstTextAt - Turn.OpenedAt}ms after the turn started`);
      }

      Publish(Turn, {
        PendingText: Turn.PendingText + Event.delta.text,
        Streamed: Turn.Streamed + Event.delta.text.length,
      });
    }

    if (Event.type === "content_block_delta" && Event.delta.type === "thinking_delta") {
      Publish(Turn, {
        PendingThinking: Turn.PendingThinking + Event.delta.thinking,
        Streamed: Turn.Streamed + Event.delta.thinking.length,
      });
    }

    if (Event.type === "content_block_start" && Event.content_block && Event.content_block.type === "tool_use") {
      const Block = Event.content_block;

      Publish(Turn, {
        Parts: Turn.Parts.concat(
          Turn.PendingThinking.trim() !== "" ? [{
            kind: "thinking",
            text: Turn.PendingThinking,
          }] : [],
          Turn.PendingText.trim() !== "" ? [{
            kind: "text",
            text: Turn.PendingText,
          }] : [],
          [{
            kind: "call",
            id: Block.id,
          }],
        ),
        CommittedThinking: JoinText(Turn.CommittedThinking, Turn.PendingThinking),
        CommittedText: JoinText(Turn.CommittedText, Turn.PendingText),
        PendingThinking: "",
        PendingText: "",
        Flushed: true,
        Activity: Turn.Activity.concat([Block.name]),
        Calls: Turn.Calls.concat([{
          Id: Block.id,
          Name: Block.name,
          Input: "",
          Output: "",
          Status: "preparing",
          StartedAt: Date.now(),
          Milliseconds: 0,
          Subagent: SubagentFor(Block, Turn.Subagent),
        }]),
      });
    }

    if (Event.type === "content_block_delta" && Event.delta.type === "input_json_delta") {
      const Last = Turn.Calls[Turn.Calls.length - 1];

      if (Last && Last.Status === "preparing") {
        Publish(Turn, {
          Calls: Turn.Calls.slice(0, -1).concat([{
            ...Last,
            Input: (Last.Input + Event.delta.partial_json).slice(0, MostCallText),
          }]),
          Streamed: Turn.Streamed + Event.delta.partial_json.length,
        });
      }
    }

    return;
  }

  if (Message.type === "assistant") {
    const Content = Blocks(Message);
    const Committed = Content.filter((Block) => Block.type === "text").map((Block) => Block.text).join("");
    const Thought = Content.filter((Block) => Block.type === "thinking").map((Block) => Block.thinking).join(NewLine);
    const Known = new Set(Turn.Calls.map((Call) => Call.Id));
    const Started = Content.filter((Block) => Block.type === "tool_use" && !Known.has(Block.id as string)).map((Block) => ({
      Id: Block.id as string,
      Name: Block.name as string,
      Input: DescribeInput(Block.input),
      Output: "",
      Status: "running" as CallStatus,
      StartedAt: Date.now(),
      Milliseconds: 0,
      Subagent: SubagentFor(Block, Turn.Subagent),
    }));
    const Readied = Turn.Calls.map((Call) => {
      const Block = Content.find((Candidate) => Candidate.type === "tool_use" && Candidate.id === Call.Id);

      return Block && Call.Status === "preparing" ? {
        ...Call,
        Input: DescribeInput(Block.input),
        Status: "running" as CallStatus,
        StartedAt: Date.now(),
      } : Call;
    });

    const Parts = Turn.Flushed ? [] : Content.map((Block) => {
      if (Block.type === "thinking") {
        return {
          kind: "thinking",
          text: Block.thinking,
        };
      }

      if (Block.type === "tool_use") {
        return {
          kind: "call",
          id: Block.id,
        };
      }

      return Block.type === "text" ? {
        kind: "text",
        text: Block.text || "",
      } : null;
    }).filter((Part) => Part && (Part.kind === "call" || (Part.text || "").trim() !== "")) as Part[];

    Publish(Turn, {
      CommittedText: Turn.Flushed ? Turn.CommittedText : JoinText(Turn.CommittedText, Committed),
      PendingText: "",
      CommittedThinking: Turn.Flushed ? Turn.CommittedThinking : JoinText(Turn.CommittedThinking, Thought),
      PendingThinking: "",
      Flushed: false,
      Parts: Turn.Parts.concat(Parts),
      Activity: Turn.Activity.concat(Started.map((Call) => Call.Name)),
      Calls: Readied.concat(Started as Call[]),
      Usage: Message.message.usage ? CountUsage(Turn.Usage, Message.message.usage) : Turn.Usage,
      Streamed: 0,
    });
    return;
  }

  if (Message.type === "user") {
    const Decoded = ImagesInContent(Message.message && Message.message.content)
      .map((Image) => DecodeImage(Image.mediaType, Image.data))
      .filter(Boolean);
    const Results = Blocks(Message).filter((Block) => Block.type === "tool_result");
    const Changes: Partial<Turn> = {};

    if (Decoded.length > 0) {
      Changes.Images = Turn.Images.concat(Decoded as SentImage[]);
    }

    if (Results.length > 0) {
      const Slots = new Map();
      let Slot = Turn.Images.length;

      for (const Result of Results) {
        const Pictures = ImagesInContent([Result]).length;

        if (Pictures > 0) {
          Slots.set(Result.tool_use_id, Slot + 1);
          Slot += Pictures;
        }
      }

      Changes.Calls = Turn.Calls.map((Call) => {
        const Result = Results.find((Block) => Block.tool_use_id === Call.Id);

        if (!Result) {
          return Call;
        }

        return {
          ...Call,
          Output: CleanOutput(Call.Name, Describe(Result.content)),
          Status: Result.is_error ? "error" : "done",
          Milliseconds: Date.now() - Call.StartedAt,
          Lines: TakeLines(Session, Call.Id),
          Image: Slots.get(Call.Id) || null,
        };
      });
    }

    const Notice = TaskNotice(TextOf(Message.message && Message.message.content));

    if (Notice) {
      Changes.Calls = (Changes.Calls || Turn.Calls).concat([Notice]);
      Changes.Parts = Turn.Parts.concat([{
        kind: "call",
        id: Notice.Id,
      }]);
    }

    if (Object.keys(Changes).length > 0) {
      Publish(Turn, Changes);
    }

    return;
  }

  if (Message.type !== "result") {
    return;
  }

  Turn.Activity = Turn.Activity.concat((Message.permission_denials || []).map((Denial: {tool_name: string}) => `denied ${Denial.tool_name}`));
  Turn.Milliseconds = Message.duration_ms || (Date.now() - Turn.StartedAt);
  const Spent = Message.total_cost_usd || 0;

  Turn.Cost = Math.max(0, Spent - (Session.Spent || 0));
  Session.Spent = Spent;

  if (Message.usage) {
    Turn.Usage = {
      Input: Message.usage.input_tokens || Turn.Usage.Input,
      Output: Message.usage.output_tokens || Turn.Usage.Output,
      Cached: Message.usage.cache_read_input_tokens || Turn.Usage.Cached,
    };
  }

  let Busiest = 0;

  for (const [Name, Usage] of Object.entries((Message.modelUsage || {}) as Record<string, {inputTokens?: number, cacheReadInputTokens?: number, contextWindow?: number}>)) {
    const Weight = (Usage.inputTokens || 0) + (Usage.cacheReadInputTokens || 0);
    const Matches = Turn.Model && Name.includes(Turn.Model.replace(/\[.*\]$/, ""));

    if (Usage.contextWindow && (Matches || Weight > Busiest)) {
      Busiest = Matches ? Infinity : Weight;
      Turn.ContextWindow = Usage.contextWindow;
      Turn.ContextModel = Name;
    }
  }

  Session.CurrentTurn = null;
  Session.LastUsedAt = Date.now();
  Session.HasSpoken = true;

  if (Turn.ConversationId && Turn.Cost > 0 && JoinText(Turn.CommittedText, Turn.PendingText) !== "") {
    RecordCost(Turn.ConversationId, Turn.Cost);
  }

  RefreshUsage(Session);
  RefreshContext(Session);
  FinishTurn(Turn, Message.is_error && Turn.Status !== "cancelling" ? "error" : (Turn.Status === "cancelling" ? "cancelled" : "done"), Message.is_error ? (Message.result || Message.subtype) : null);

  if (!KeepSessionsWarm) {
    Session.Close();
    return;
  }

  CloseIdleSessions();
}

const Ladder = ["claude-fable-5-1", "claude-fable-5", "opus", "claude-opus-5", "claude-opus-4-8", "claude-opus-4-7", "claude-opus-4-6", "sonnet", "claude-sonnet-4-6", "haiku"];

export function LadderBelow(Model: string): string[] {
  const Plain = Model.replace(/\[1m\]$/, "");
  const Placed = Plain === "default" || Plain === "claude-opus-5" ? "opus" : (Plain === "claude-sonnet-5" ? "sonnet" : Plain);
  const Index = Ladder.indexOf(Placed);

  return Index >= 0 ? Ladder.slice(Index + 1) : Ladder.slice(Ladder.indexOf("opus"));
}

function OpenSession(ConversationId: string | null, TurnWorkingDirectory: string, Model: string, Effort: string | null, AskForTools: boolean, ExtraPrompt: boolean, FastMode: boolean, Planning: boolean, UsingSubagents: boolean, Mode: string, Bypass: boolean, Subagent: string, OutputStyle: string, StepDown: boolean): Session {
  const Pending: unknown[] = [];
  let Wake: ((Value?: unknown) => void) | null = null;
  let Ended = false;

  const Session: Session = {
    Key: ConversationId || `pending-${Math.random().toString(36).slice(2, 10)}`,
    ConversationId,
    Model,
    Effort,
    Subagent,
    AskForTools,
    ExtraPrompt: ExtraPrompt !== false,
    FastMode: FastMode === true,
    OutputStyle,
    StepDown,
    WorkingDirectory: TurnWorkingDirectory,
    Planning: Planning === true,
    Mode: PermissionModeFor(Mode, Bypass),
    UsingSubagents: UsingSubagents === true,
    GuardTools: false,
    FilesBefore: new Map(),
    LineCounts: new Map(),
    CurrentTurn: null,
    LastUsedAt: Date.now(),
    Query: null,
    Send(Message: unknown) {
      Pending.push(Message);

      if (Wake) {
        const Resume = Wake;

        Wake = null;
        Resume();
      }
    },
    Close() {
      if (Ended) {
        return;
      }

      Ended = true;
      Session.Ended = true;

      if (Spare === Session) {
        Spare = null;
      }

      if (Sessions.get(Session.Key) === Session) {
        Sessions.delete(Session.Key);
      }

      SessionAllowances.delete(Session.Key);

      if (Session.Query) {
        Session.Query.return().catch(() => {});
      }

      if (Wake) {
        const Resume = Wake;

        Wake = null;
        Resume();
      }
    },
  };

  async function* Input() {
    while (!Ended) {
      if (Pending.length === 0) {
        await new Promise((Resolve) => {
          Wake = Resolve;
        });
        continue;
      }

      yield Pending.shift() as SDKUserMessage;
    }
  }

  Sessions.set(Session.Key, Session);

  const Run = async () => {
    try {
      Session.Query = query({
        prompt: Input(),
        options: {
          resume: ConversationId || undefined,
          model: Model,
          effort: (Effort || undefined) as EffortLevel | undefined,
          cwd: TurnWorkingDirectory,
          additionalDirectories: [MirrorSyncedSkills()],
          includePartialMessages: true,
          settings: {
            fastMode: FastMode === true,
            todoFeatureEnabled: true,
            outputStyle: OutputStyle,
          },
          fallbackModel: StepDown && LadderBelow(Model).length > 0 ? LadderBelow(Model).join(",") : undefined,
          thinking: {
            type: "adaptive",
            display: "summarized",
          },
          permissionMode: Session.Mode as PermissionMode,
          planModeInstructions: PlanInstructions,
          agents: Session.UsingSubagents ? AgentsOn(Session.Subagent) as Record<string, AgentDefinition> : undefined,
          skills: Session.UsingSubagents ? [] : undefined,
          hooks: {
            PreToolUse: [{
              hooks: [async (HookInput, ToolUseId, Options) => {
                const Asked = HookInput as {tool_name: string, tool_input: unknown};
                const Edited = EditedFile(Asked.tool_name, Asked.tool_input);

                if (Edited && ToolUseId) {
                  Session.FilesBefore.set(ToolUseId, ReadFileText(Edited));
                }

                if ((IsAllowedTool(Asked.tool_name) || !Session.AskForTools) && !(Session.GuardTools && IsRisky(Asked.tool_name, Asked.tool_input))) {
                  return {hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: "allow",
                  }};
                }

                if (!Session.CurrentTurn) {
                  return {
                    hookSpecificOutput: {
                      hookEventName: "PreToolUse",
                      permissionDecision: "deny",
                      permissionDecisionReason: "Claudio had no open turn to ask in.",
                    },
                  };
                }

                const Result = await AskPermission(Session.CurrentTurn, Asked.tool_name, Asked.tool_input, Options);

                return {
                  hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: (Result as {behavior?: string}).behavior === "allow" ? "allow" : "deny",
                    permissionDecisionReason: (Result as {message?: string}).message || "Answered in Claudio",
                  },
                };
              }],
            }],
            UserPromptSubmit: [{
              hooks: [async (HookInput) => {
                const Sent = HookInput as {source?: string};

                if (Sent && Sent.source && Sent.source !== "user") {
                  return {};
                }

                const Context = Session.PendingContext;

                Session.PendingContext = "";

                if (!Context) {
                  return {};
                }

                Session.Place = Session.PendingPlace || Session.Place;

                return {hookSpecificOutput: {
                  hookEventName: "UserPromptSubmit",
                  additionalContext: Context,
                }};
              }],
            }],
            PostToolUse: [{
              hooks: [async (HookInput, ToolUseId) => {
                const Asked = HookInput as {tool_name: string, tool_input: unknown};
                const Edited = EditedFile(Asked.tool_name, Asked.tool_input);

                if (Edited && ToolUseId && Session.FilesBefore.has(ToolUseId)) {
                  Session.LineCounts.set(ToolUseId, CountLines(Session.FilesBefore.get(ToolUseId) as string, ReadFileText(Edited)));
                  Session.FilesBefore.delete(ToolUseId);
                }

                if (ToolUseId && /__source$/.test(Asked.tool_name)) {
                  const Said = JSON.stringify((HookInput as {tool_response?: unknown}).tool_response || "");
                  const Shown = Said.match(/ \+(\d+) -(\d+)/);

                  if (Shown) {
                    Session.LineCounts.set(ToolUseId, {
                      added: Number(Shown[1]),
                      removed: Number(Shown[2]),
                    });
                  }
                }

                if (!Session.CapResults) {
                  return {};
                }

                const Finished = HookInput as {tool_name: string, tool_response: unknown};
                const Capped = CapToolOutput(Finished.tool_name, Finished.tool_response as any);

                if (!Capped) {
                  return {};
                }

                return {hookSpecificOutput: {
                  hookEventName: "PostToolUse",
                  updatedToolOutput: Capped,
                }};
              }],
            }],
          },
          mcpServers: {
            ...ReadMcpServers(),
            [AskServerName]: AskServerFor((Questions) => AskQuestion(Session, Questions) as Promise<JobAnswer | null>, ((Kind, Input, Timeout) => RequestStudio(Kind, Input, JobLimit(Kind, Timeout))) as Reacher, ((Role, Kind, Input, Timeout) => RequestStudio(Kind, Input, JobLimit(Kind, Timeout), Role)) as ReacherIn),
          },
          systemPrompt: {
            type: "preset",
            preset: "claude_code",
            append: ExtraPrompt === false ? "" : SystemPromptFor(Object.keys(ReadMcpServers()), Session.UsingSubagents),
          },
        },
      });

      for await (const Message of Session.Query) {
        RouteMessage(Session, Message);
      }

      if (Session.CurrentTurn) {
        FinishTurn(Session.CurrentTurn, Session.CurrentTurn.Status === "cancelling" ? "cancelled" : "done");
      }
    } catch (Error) {
      if (Session.CurrentTurn) {
        FinishTurn(Session.CurrentTurn, Session.CurrentTurn.Status === "cancelling" ? "cancelled" : "error", (Error as Error).message);
      }

      console.error(`Session ${Session.Key} ended: ${(Error as Error).message}`);
    }

    Session.CurrentTurn = null;
    Session.Close();
  };

  Run();

  return Session;
}

let Spare: Session | null = null;

function TakeSpare(Model: string, Effort: string | null) {
  const Ready = Spare;

  if (!Ready || Ready.Ended || Ready.CurrentTurn || Ready.Model !== Model || (Ready.Effort || null) !== (Effort || null)) {
    return null;
  }

  Spare = null;
  return Ready;
}

let LastFolder: string | null = null;

export function LastUsedFolder() {
  return LastFolder;
}

export function KeepSpareWarm() {
  if (!KeepSessionsWarm || Spare) {
    return;
  }

  if (!LastFolder) {
    LastFolder = UsableFolder(ReadPluginSetting("WorkingFolder")) || WorkingDirectory;
  }

  const Likely = AutoTier(0, AutoBias(ReadPluginSetting("Effort") as string | null));

  Spare = OpenSession(null, LastFolder, Likely.model, Likely.effort, true, true, false, false, false, DefaultMode, false, Likely.delegate, LastStyle, LastStepDown);
}

function EffortRank(Effort: string | null) {
  return EffortOrder.indexOf(Effort || "none");
}

export function UsableFolder(Folder: unknown): string | null {
  if (typeof Folder !== "string" || Folder.trim() === "") {
    return null;
  }

  try {
    return fs.statSync(Folder).isDirectory() ? path.resolve(Folder) : null;
  } catch {
    return null;
  }
}

function DescribePlace(Place: {name?: string, placeId?: number, universeId?: number} | null | undefined): string | null {
  if (!Place || typeof Place.name !== "string" || Place.name === "") {
    return null;
  }

  const Said = (!Place.placeId || !Place.universeId)
    ? `The open place is ${JSON.stringify(String(Place.name).replace(/\s+/g, " ").slice(0, 100))}. It has not been published, so it has no place id or universe id yet.`
    : `The open place is ${JSON.stringify(String(Place.name).replace(/\s+/g, " ").slice(0, 100))}, place id ${Place.placeId}, universe id ${Place.universeId}.`;

  return `<studio_place>\n${Said}\n</studio_place>`;
}

let LastStyle = "default";
let LastStepDown = true;

function ApplyStyle(Session: Session, OutputStyle: string, StepDown: boolean) {
  if (Session.OutputStyle === OutputStyle && Session.StepDown === StepDown) {
    return;
  }

  Session.OutputStyle = OutputStyle;
  Session.StepDown = StepDown;

  if (!Session.Query) {
    return;
  }

  const Below = LadderBelow(Session.Model);

  Session.Query.applyFlagSettings({
    outputStyle: OutputStyle,
    fallbackModel: StepDown && Below.length > 0 ? Below : null,
  }).catch((Trouble: unknown) => {
    console.error(`Could not apply the ${OutputStyle} style to ${Session.Key}: ${Trouble}`);
  });
}

export function ApplyStyleEverywhere(OutputStyle: string, StepDown: boolean) {
  LastStyle = OutputStyle;
  LastStepDown = StepDown;

  for (const Session of Sessions.values()) {
    if (!Session.Ended) {
      ApplyStyle(Session, OutputStyle, StepDown);
    }
  }

  if (Spare && !Spare.Ended) {
    ApplyStyle(Spare, OutputStyle, StepDown);
  }
}

export function StartTurn({ Text, ConversationId, Images, Model, Effort, AskForTools, GuardTools, Escalate, ExtraPrompt, FastMode, Mode, Bypass, Place, Folder, OutputStyle, StepDown }: TurnRequest) {
  LastStyle = OutputStyle || "default";
  LastStepDown = StepDown !== false;

  const Existing = ConversationId ? GetConversation(ConversationId) : null;
  const Lean = Model === LeanMode.value;
  const Auto = Lean || !Model || Model === "auto";
  const Planning = Mode === "plan";

  if (Escalate && Auto) {
    RecordTurnOutcome(ConversationId || "", {
      Failed: true,
      Denied: false,
    });
  }

  const Chosen = Auto
    ? ChooseModel(ConversationId || "", Text, Boolean(Images && Images.length) || Text.includes("<studio_context>"), AutoBias(Effort))
    : {
      model: Model,
      effort: Escalate ? NextEffort(Model, Effort) : (SupportsEffort(Model, Effort) ? Effort : null),
      delegate: "",
    };
  const Turn: Turn = {
    Id: `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`,
    ConversationId,
    Prompt: Text,
    Auto,
    CapResults: Lean,
    Planning,
    UsingSubagents: Lean,
    Tasks: [],
    Model: Chosen.model,
    Effort: Chosen.effort,
    Subagent: Chosen.delegate || SubagentModels[0],
    AskForTools: AskForTools !== false,
    GuardTools: GuardTools === true,
    ExtraPrompt: ExtraPrompt !== false,
    FastMode: FastMode === true,
    Bypass: Bypass === true,
    Mode,
    WorkingDirectory: (Existing && UsableFolder(Existing.workingDirectory)) || UsableFolder(Folder) || WorkingDirectory,
    SessionId: ConversationId,
    Status: "running",
    CommittedText: "",
    PendingText: "",
    CommittedThinking: "",
    PendingThinking: "",
    Parts: [],
    Flushed: false,
    Streamed: 0,
    Compacting: false,
    OutputStyle: LastStyle,
    StepDown: LastStepDown,
    FallenFrom: null,
    Activity: [],
    Calls: [],
    Usage: {
      Input: 0,
      Output: 0,
      Cached: 0,
    },
    StartedAt: Date.now(),
    Milliseconds: 0,
    Cost: 0,
    ContextWindow: 0,
    ContextModel: null,
    Images: [],
    Delivered: {},
    Permissions: [],
    PermissionCount: 0,
    Question: null,
    Error: null,
    Version: 0,
    Waiters: [],
  };

  Turns.set(Turn.Id, Turn);
  LastFolder = Turn.WorkingDirectory;

  const Warm = ConversationId ? Sessions.get(ConversationId) : TakeSpare(Chosen.model, Chosen.effort);
  const Reusable = Warm && !Warm.CurrentTurn && !Warm.Ended && EffortRank(Chosen.effort) <= EffortRank(Warm.Effort) && Warm.ExtraPrompt === Turn.ExtraPrompt && Warm.FastMode === Turn.FastMode && Warm.WorkingDirectory === Turn.WorkingDirectory && Warm.Planning === Turn.Planning && Warm.Mode === PermissionModeFor(Turn.Mode, Turn.Bypass) && Warm.UsingSubagents === Turn.UsingSubagents && Warm.Subagent === Turn.Subagent;

  if (Warm && !Reusable) {
    const Reasons = [
      Warm.CurrentTurn && "busy",
      Warm.Ended && "ended",
      EffortRank(Chosen.effort) > EffortRank(Warm.Effort) && `effort ${Warm.Effort || "none"} under ${Chosen.effort || "none"}`,
      Warm.ExtraPrompt !== Turn.ExtraPrompt && "extra prompt",
      Warm.FastMode !== Turn.FastMode && "fast mode",
      Warm.WorkingDirectory !== Turn.WorkingDirectory && "folder",
      Warm.Planning !== Turn.Planning && "planning",
      Warm.Mode !== PermissionModeFor(Turn.Mode, Turn.Bypass) && `mode ${Warm.Mode} not ${PermissionModeFor(Turn.Mode, Turn.Bypass)}`,
      Warm.UsingSubagents !== Turn.UsingSubagents && "delegating",
      Warm.Subagent !== Turn.Subagent && "delegate",
    ].filter(Boolean);

    console.log(`Turn ${Turn.Id}: closing the ${ConversationId ? "kept" : "spare"} session, ${Reasons.join(", ")}`);
    Warm.Close();
  }

  if (!ConversationId && !Warm) {
    console.log(`Turn ${Turn.Id}: no spare session was waiting${Spare ? ` (spare is ${Spare.Model} ${Spare.Effort || "none"}, wanted ${Chosen.model} ${Chosen.effort || "none"})` : ""}`);
  }

  Turn.OpenedAt = Date.now();
  Turn.Cold = !Reusable;

  if (Reusable) {
    Turn.Effort = Warm.Effort;
  }

  const Session = (Reusable ? Warm : null) || OpenSession(ConversationId, Turn.WorkingDirectory, Chosen.model, Turn.Effort, Turn.AskForTools, Turn.ExtraPrompt, Turn.FastMode, Turn.Planning, Turn.UsingSubagents, Turn.Mode, Turn.Bypass, Turn.Subagent, Turn.OutputStyle, Turn.StepDown);

  if (Session.Model !== Chosen.model && Session.Query) {
    Session.Model = Chosen.model;
    Session.Query.setModel(Chosen.model).catch(() => {});
  }

  ApplyStyle(Session, Turn.OutputStyle, Turn.StepDown);

  if (!ConversationId) {
    setTimeout(KeepSpareWarm, 1000);
  }

  Turn.Session = Session;
  Session.AskForTools = Turn.AskForTools;
  Session.GuardTools = Turn.GuardTools;
  Session.CapResults = Turn.CapResults;
  Session.Planning = Turn.Planning;
  Session.Mode = PermissionModeFor(Turn.Mode, Turn.Bypass);
  Session.UsingSubagents = Turn.UsingSubagents;
  Session.CurrentTurn = Turn;
  Session.LastUsedAt = Date.now();

  const Described = DescribePlace(Place);
  const NewPlace = Described && Described !== Session.Place ? Described : "";
  const VisibleText = StripContext(Text);
  const CarriedContext = [NewPlace, ExtractContext(Text)].filter(Boolean).join("\n\n");

  if (VisibleText === "" || CarriedContext === "") {
    Session.PendingContext = "";
    Session.PendingPlace = "";
    Session.Place = NewPlace || Session.Place;
    Session.Send(UserMessage(NewPlace ? NewPlace + "\n\n" + Text : Text, Images));

    return Turn;
  }

  Session.PendingContext = CarriedContext;
  Session.PendingPlace = NewPlace;
  Session.Send(UserMessage(VisibleText, Images));

  return Turn;
}

export function GetTurn(Id: string) {
  return Turns.get(Id);
}

export function CancelTurn(Turn: Turn) {
  if (Turn.Status !== "running") {
    return;
  }

  Publish(Turn, {Status: "cancelling"});
  setTimeout(() => FinishTurn(Turn, "cancelled"), CancelGraceMilliseconds);

  const Session = Turn.Session;

  if (!Session || !Session.Query) {
    FinishTurn(Turn, "cancelled");
    return;
  }

  Session.Query.interrupt().catch(() => {
    Session.Close();
    FinishTurn(Turn, "cancelled");
  });
}

export function CloseConversation(Id: string) {
  const Session = Sessions.get(Id);

  if (!Session) {
    return;
  }

  if (Session.CurrentTurn) {
    CancelTurn(Session.CurrentTurn);
  }

  Session.Close();
}

export function AbortAllTurns() {
  for (const Session of [...Sessions.values()]) {
    Session.Close();
  }

  for (const Turn of Turns.values()) {
    if (Turn.Status === "running" || Turn.Status === "cancelling") {
      FinishTurn(Turn, "cancelled");
    }
  }
}

export function ReleaseImage(Turn: Turn, Index: number) {
  Turn.Delivered[Index] = true;

  if (Turn.Status === "running" || Turn.Images.length === 0) {
    return;
  }

  for (let Number = 1; Number <= Turn.Images.length; Number += 1) {
    if (!Turn.Delivered[Number]) {
      return;
    }
  }

  Turn.Images = [];
}

export function WaitForChange(Turn: Turn, KnownVersion: number, Milliseconds: number) {
  if (Turn.Version > KnownVersion) {
    return Settle(Turn);
  }

  return new Promise((Resolve) => {
    const Waiter = () => {
      clearTimeout(Timer);
      Settle(Turn).then(Resolve);
    };
    const Timer = setTimeout(() => {
      Turn.Waiters.splice(Turn.Waiters.indexOf(Waiter), 1);
      Resolve(undefined);
    }, Milliseconds);

    Turn.Waiters.push(Waiter);
  });
}

function Settle(Turn: Turn) {
  if (Turn.Status !== "running") {
    return Promise.resolve();
  }

  return new Promise((Resolve) => {
    setTimeout(Resolve, CoalesceMilliseconds);
  });
}

export function DescribeTurn(Turn: Turn) {
  Turn.OutputShown = Math.max(Turn.OutputShown || 0, Turn.Usage.Output + Math.ceil(Turn.Streamed / 4));

  return {
    requestId: Turn.Id,
    conversationId: Turn.ConversationId,
    sessionId: Turn.SessionId,
    status: Turn.Status === "cancelling" ? "running" : Turn.Status,
    text: JoinText(Turn.CommittedText, Turn.PendingText),
    thinking: JoinText(Turn.CommittedThinking, Turn.PendingThinking),
    parts: Turn.Parts.concat(
      Turn.PendingThinking.trim() !== "" ? [{
        kind: "thinking",
        text: Turn.PendingThinking,
      }] : [],
      Turn.PendingText.trim() !== "" ? [{
        kind: "text",
        text: Turn.PendingText,
      }] : [],
    ).map((Part) => (Part.kind === "call" ? {
      kind: "call",
      call: Turn.Calls.findIndex((Call) => Call.Id === Part.id) + 1,
    } : Part)),
    activity: Turn.Activity,
    model: Turn.Model,
    effort: Turn.Effort,
    auto: Turn.Auto,
    imageCount: Turn.Images.length,
    question: Turn.Question ? {
      id: Turn.Question.Id,
      questions: Turn.Question.Questions,
    } : null,
    permission: Turn.Permissions.length > 0
      ? {
        id: Turn.Permissions[0].Id,
        tool: Turn.Permissions[0].ToolName,
        input: JSON.stringify(Turn.Permissions[0].Input).slice(0, 600),
      }
      : null,
    error: Turn.Error,
    calls: Turn.Calls.map((Call) => ({
      name: Call.Name,
      input: Call.Input,
      output: Call.Output,
      status: Call.Status,
      steps: Call.Steps || [],
      milliseconds: Call.Milliseconds,
      delegate: Call.Subagent || null,
      lines: Call.Lines || null,
      image: Call.Image || null,
    })),
    tasks: Turn.Tasks.map((Task) => ({
      id: Task.Id,
      description: Task.Description,
      kind: Task.Kind,
      status: Task.Status,
      background: Task.Background,
      depth: Task.Depth,
    })),
    planning: Turn.Planning === true,
    compacting: Turn.Compacting === true,
    milliseconds: Turn.Milliseconds || (Turn.Status === "running" ? Date.now() - Turn.StartedAt : 0),
    tokens: {
      input: Turn.Usage.Input,
      output: Turn.OutputShown,
      cached: Turn.Usage.Cached,
    },
    limits: GetLimits(),
    context: (Turn.Session && Turn.Session.Breakdown) || null,
    contextWindow: Turn.ContextWindow || 0,
    contextModel: Turn.ContextModel || null,
    cost: Turn.Cost,
    version: Turn.Version,
  };
}

export async function ForkConversation(ConversationId: string) {
  const Result = await forkSession(ConversationId) as {sessionId?: string};

  return Result.sessionId;
}