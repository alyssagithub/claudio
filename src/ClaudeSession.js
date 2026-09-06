import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { forkSession, query } from "@anthropic-ai/claude-agent-sdk";
import { AllowedTools, AutoTiers, CancelGraceMilliseconds, CoalesceMilliseconds, EffortOrder, CommandsCacheFile, DesktopConfigPath, FinishedTurnLifetimeMilliseconds, IdleSessionMilliseconds, KeepSessionsWarm, MaxWarmSessions, SystemPromptFor, WorkingDirectory } from "./Config.js";
import { AddDesktopSession, GetConversation, RecordCost, RememberOwnSession, StripContext, UpdateDesktopSession } from "./Conversations.js";
import { DecodeImage, ImagesInContent } from "./Images.js";
import { ChooseModel, GetModels, NextEffort, RecordTurnOutcome, RememberModels, SupportsEffort } from "./Models.js";

const Turns = new Map();
const Sessions = new Map();
const SessionAllowances = new Map();
const AllowedServers = AllowedTools
  .filter((Name) => Name.startsWith("mcp__"))
  .map((Name) => Name.split("__")[1]);

function ReadCommandsCache() {
  try {
    return { ...JSON.parse(fs.readFileSync(CommandsCacheFile, "utf8")), ready: true };
  } catch {
    return { slashCommands: [], skills: [], ready: false };
  }
}

let Commands = ReadCommandsCache();
let AskedForModels = false;
let Limits = new Map();

export function GetLimits() {
  return [...Limits.values()];
}

function Blocks(Message) {
  const Content = Message.message && Message.message.content;

  return Array.isArray(Content) ? Content : [];
}

function StoreWindow(Into, Kind, Label, Entry) {
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

export function GetBreakdown(ConversationId) {
  const Session = ConversationId ? Sessions.get(ConversationId) : null;

  return (Session && Session.Breakdown) || null;
}

function Rank(Entry) {
  if (Entry.deferred) {
    return 3;
  }

  return /free space/i.test(Entry.name) ? 2 : 1;
}

export async function RefreshContext(Session) {
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
        .map((Entry) => ({
          name: Entry.name,
          tokens: Entry.tokens || 0,
          colour: String(Entry.color || ""),
          deferred: Entry.isDeferred === true,
        }))
        .sort((Left, Right) => Rank(Left) - Rank(Right) || Right.tokens - Left.tokens),
    };
  } catch (Error) {
    console.error("Could not read context usage: " + Error.message);
  }
}

export async function PollUsage(ConversationId) {
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

export async function RefreshUsage(Session) {
  const Ask = Session.Query && Session.Query.usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET;

  if (!Ask) {
    return;
  }

  try {
    const Usage = await Ask.call(Session.Query);
    const Windows = Usage && Usage.rate_limits;

    if (!Windows) {
      return;
    }

    const Fresh = new Map();

    StoreWindow(Fresh, "five_hour", "5-hour limit", Windows.five_hour);
    StoreWindow(Fresh, "seven_day", "Weekly - all models", Windows.seven_day);
    StoreWindow(Fresh, "seven_day_opus", "Weekly - Opus", Windows.seven_day_opus);
    StoreWindow(Fresh, "seven_day_sonnet", "Weekly - Sonnet", Windows.seven_day_sonnet);

    for (const Scoped of Windows.model_scoped || []) {
      StoreWindow(Fresh, "model:" + Scoped.display_name, "Weekly - " + Scoped.display_name, Scoped);
    }

    Limits = Fresh;
  } catch (Error) {
    console.error("Could not read usage: " + Error.message);
  }
}

export function ReadMcpServers() {
  try {
    const Desktop = JSON.parse(fs.readFileSync(DesktopConfigPath, "utf8"));
    const Servers = {};

    for (const [Name, Definition] of Object.entries(Desktop.mcpServers || {})) {
      if (!Definition.command || !AllowedServers.includes(Name)) {
        continue;
      }

      Servers[Name] = { command: Definition.command, args: Definition.args || [], env: Definition.env };
    }

    return Servers;
  } catch (Error) {
    console.error(`Could not read MCP servers from ${DesktopConfigPath}: ${Error.message}`);
    return {};
  }
}

const Destructive = /destroy|:remove\(|clearallchildren/i;

function IsRisky(ToolName, Input) {
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

function IsAllowedTool(ToolName) {
  return AllowedTools.some((Pattern) => Pattern.endsWith("*") ? ToolName.startsWith(Pattern.slice(0, -1)) : ToolName === Pattern);
}

let ServerStatuses = {};

export function GetMcpServers() {
  const Configured = ReadMcpServers();

  return Object.entries(Configured).map(([Name, Definition]) => ({
    name: Name,
    command: Definition.command,
    arguments: (Definition.args || []).join(" "),
    status: ServerStatuses[Name] || "unknown",
  }));
}

function RememberServers(Init) {
  for (const Server of Init.mcp_servers || []) {
    ServerStatuses[Server.name] = Server.status;
  }
}

function ReadDescription(File) {
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

function ReadFolder(Folder) {
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

function ReadDescriptions() {
  const Found = {};
  const SkillsRoot = path.join(os.homedir(), ".claude", "skills");
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

function RememberCommands(Init) {
  Commands = {
    slashCommands: Init.slash_commands || [],
    skills: Init.skills || [],
    ready: true,
  };

  try {
    fs.mkdirSync(path.dirname(CommandsCacheFile), { recursive: true });
    fs.writeFileSync(CommandsCacheFile, JSON.stringify({ slashCommands: Commands.slashCommands, skills: Commands.skills }));
  } catch {
    return;
  }
}

let Described = null;
let DescribedAt = 0;

export function GetCommands() {
  if (!Described || Date.now() - DescribedAt > 60000) {
    Described = ReadDescriptions();
    DescribedAt = Date.now();
  }

  return {
    ...Commands,
    commands: Commands.slashCommands.map((Name) => ({ name: Name, description: Described[Name] || "" })),
  };
}

export async function DiscoverCommands() {
  if (Commands.ready) {
    return;
  }

  try {
    for await (const Message of query({
      prompt: "Reply with the single word ready.",
      options: {
        cwd: WorkingDirectory,
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
      }
    }
  } catch (Error) {
    console.error(`Could not discover commands: ${Error.message}`);
  }
}

const NewLine = "\n";

function Describe(Value) {
  if (typeof Value === "string") {
    return Value.slice(0, 4000);
  }

  if (Array.isArray(Value)) {
    return Value.map((Block) => (Block && Block.type === "text" ? Block.text : JSON.stringify(Block))).join(NewLine).slice(0, 4000);
  }

  try {
    return JSON.stringify(Value, null, 2).slice(0, 4000);
  } catch {
    return String(Value).slice(0, 4000);
  }
}

function DescribeInput(Input) {
  if (!Input || typeof Input !== "object" || Array.isArray(Input)) {
    return Describe(Input);
  }

  return Object.entries(Input)
    .map(([Name, Value]) => `${Name}: ${typeof Value === "string" ? Value : JSON.stringify(Value)}`)
    .join(NewLine)
    .slice(0, 4000);
}

function CountUsage(Existing, Usage) {
  return {
    Input: Existing.Input + (Usage.input_tokens || 0),
    Output: Existing.Output + (Usage.output_tokens || 0),
    Cached: Existing.Cached + (Usage.cache_read_input_tokens || 0),
  };
}

function Publish(Turn, Changes) {
  Object.assign(Turn, Changes);
  Turn.Version += 1;

  for (const Resolve of Turn.Waiters.splice(0)) {
    Resolve();
  }
}

function JoinText(Existing, Added) {
  if (Existing === "" || Added === "") {
    return Existing + Added;
  }

  return `${Existing}\n\n${Added}`;
}

function FinishTurn(Turn, Status, Error) {
  if (Turn.Status !== "running" && Turn.Status !== "cancelling") {
    return;
  }

  const Text = JoinText(Turn.CommittedText, Turn.PendingText);

  if (Turn.ConversationId) {
    UpdateDesktopSession(Turn.ConversationId, (Session) => {
      Session.lastActivityAt = Date.now();
      Session.completedTurns = (Session.completedTurns || 0) + 1;
    });
  }

  for (const Permission of Turn.Permissions.splice(0)) {
    Permission.Resolve({ behavior: "deny", message: "The turn ended before the user answered." });
  }

  RecordTurnOutcome(Turn.ConversationId, {
    Failed: Status === "error",
    Denied: Turn.Activity.some((Name) => Name.startsWith("denied ")),
  });
  if (Turn.Session && Turn.Session.CurrentTurn === Turn) {
    Turn.Session.CurrentTurn = null;
  }

  Publish(Turn, { Status, Error: Error || null, CommittedText: Text, PendingText: "" });
  setTimeout(() => Turns.delete(Turn.Id), FinishedTurnLifetimeMilliseconds);
}

export function IsConversationBusy(ConversationId) {
  for (const Turn of Turns.values()) {
    if (Turn.ConversationId === ConversationId && (Turn.Status === "running" || Turn.Status === "cancelling")) {
      return true;
    }
  }

  return false;
}

function AllowanceKey(Turn) {
  return Turn.Session && Turn.Session.ConversationId ? Turn.Session.Key : Turn.Id;
}

function AskPermission(Turn, ToolName, Input, Options) {
  const Allowed = SessionAllowances.get(AllowanceKey(Turn));

  if (Allowed && Allowed.has(ToolName)) {
    return Promise.resolve({ behavior: "allow", updatedInput: Input });
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

        if (Index !== -1) {
          Turn.Permissions.splice(Index, 1);
          Publish(Turn, {});
        }

        Resolve({ behavior: "deny", message: "Cancelled." });
      });
    }
  });
}

export function AnswerPermission(Turn, PermissionId, Allow, Always) {
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

    SessionAllowances.get(Key).add(Permission.ToolName);
  }

  Publish(Turn, {});
  Permission.Resolve(Allow
    ? { behavior: "allow", updatedInput: Permission.Input }
    : { behavior: "deny", message: "The user declined this tool use in Claudio." });
  return true;
}

function UserMessage(Text, Images) {
  const Pictures = (Images || []).map((Image) => ({
    type: "image",
    source: { type: "base64", media_type: Image.mediaType, data: Image.data },
  }));

  return {
    type: "user",
    message: { role: "user", content: Pictures.concat([{ type: "text", text: Text }]) },
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

function CleanOutput(Name, Text) {
  if (Name !== "Agent" && Name !== "Task") {
    return Text;
  }

  if (!/agentId|launched successfully/i.test(Text)) {
    return Text;
  }

  return "Ran in the background. Its steps are listed above and its report is in the reply.";
}

function RecordStep(Turn, Message) {
  const Call = Turn.Calls.find((Entry) => Entry.Id === Message.parent_tool_use_id);

  if (!Call || Message.type !== "assistant") {
    return;
  }

  const Lines = [];

  for (const Block of Blocks(Message)) {
    if (Block.type === "tool_use") {
      Lines.push(`Used ${Block.name}`);
    }

    if (Block.type === "text" && Block.text.trim() !== "") {
      Lines.push(Block.text.trim().replace(/\s+/g, " ").slice(0, 200));
    }
  }

  if (Lines.length === 0) {
    return;
  }

  Call.Steps = (Call.Steps || []).concat(Lines).slice(-40);
  Publish(Turn, { Calls: Turn.Calls.slice() });
}

function RouteMessage(Session, Message) {
  const Turn = Session.CurrentTurn;


  if (Message.type === "system" && Message.subtype === "init") {
    RememberCommands(Message);
    RememberServers(Message);
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
      Session.Query.supportedModels().then(RememberModels).catch(() => {});
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

    Publish(Turn, { SessionId: Message.session_id, ConversationId: Message.session_id });
    return;
  }

  if (Message.type === "stream_event") {
    const Event = Message.event;

    if (Event.type === "content_block_delta" && Event.delta.type === "text_delta") {
      Publish(Turn, { PendingText: Turn.PendingText + Event.delta.text });
    }

    if (Event.type === "content_block_delta" && Event.delta.type === "thinking_delta") {
      Publish(Turn, { PendingThinking: Turn.PendingThinking + Event.delta.thinking });
    }

    return;
  }

  if (Message.type === "assistant") {
    const Content = Blocks(Message);
    const Committed = Content.filter((Block) => Block.type === "text").map((Block) => Block.text).join("");
    const Thought = Content.filter((Block) => Block.type === "thinking").map((Block) => Block.thinking).join(NewLine);
    const Started = Content.filter((Block) => Block.type === "tool_use").map((Block) => ({
      Id: Block.id,
      Name: Block.name,
      Input: DescribeInput(Block.input),
      Output: "",
      Status: "running",
      StartedAt: Date.now(),
      Milliseconds: 0,
    }));

    Publish(Turn, {
      CommittedText: JoinText(Turn.CommittedText, Committed),
      PendingText: "",
      CommittedThinking: JoinText(Turn.CommittedThinking, Thought),
      PendingThinking: "",
      Activity: Turn.Activity.concat(Started.map((Call) => Call.Name)),
      Calls: Turn.Calls.concat(Started),
      Usage: Message.message.usage ? CountUsage(Turn.Usage, Message.message.usage) : Turn.Usage,
    });
    return;
  }

  if (Message.type === "user") {
    const Decoded = ImagesInContent(Message.message && Message.message.content)
      .map((Image) => DecodeImage(Image.mediaType, Image.data))
      .filter(Boolean);
    const Results = Blocks(Message).filter((Block) => Block.type === "tool_result");
    const Changes = {};

    if (Decoded.length > 0) {
      Changes.Images = Turn.Images.concat(Decoded);
    }

    if (Results.length > 0) {
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
        };
      });
    }

    if (Object.keys(Changes).length > 0) {
      Publish(Turn, Changes);
    }

    return;
  }

  if (Message.type !== "result") {
    return;
  }

  Turn.Activity = Turn.Activity.concat((Message.permission_denials || []).map((Denial) => `denied ${Denial.tool_name}`));
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

  for (const [Name, Usage] of Object.entries(Message.modelUsage || {})) {
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

function OpenSession(ConversationId, TurnWorkingDirectory, Model, Effort, AskForTools, ExtraPrompt, FastMode) {
  const Pending = [];
  let Wake = null;
  let Ended = false;

  const Session = {
    Key: ConversationId || `pending-${Math.random().toString(36).slice(2, 10)}`,
    ConversationId,
    Model,
    Effort,
    AskForTools,
    ExtraPrompt: ExtraPrompt !== false,
    FastMode: FastMode === true,
    WorkingDirectory: TurnWorkingDirectory,
    GuardTools: false,
    CurrentTurn: null,
    LastUsedAt: Date.now(),
    Query: null,
    Send(Message) {
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

      yield Pending.shift();
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
          effort: Effort || undefined,
          cwd: TurnWorkingDirectory,
          includePartialMessages: true,
          settings: { fastMode: FastMode === true },
          thinking: { type: "adaptive", display: "summarized" },
          permissionMode: "default",
          hooks: {
            PreToolUse: [{
              hooks: [async (HookInput, ToolUseId, Options) => {
                if ((IsAllowedTool(HookInput.tool_name) || !Session.AskForTools) && !(Session.GuardTools && IsRisky(HookInput.tool_name, HookInput.tool_input))) {
                  return { hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "allow" } };
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

                const Result = await AskPermission(Session.CurrentTurn, HookInput.tool_name, HookInput.tool_input, Options);

                return {
                  hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: Result.behavior === "allow" ? "allow" : "deny",
                    permissionDecisionReason: Result.message || "Answered in Claudio",
                  },
                };
              }],
            }],
          },
          mcpServers: ReadMcpServers(),
          systemPrompt: { type: "preset", preset: "claude_code", append: ExtraPrompt === false ? "" : SystemPromptFor(Object.keys(ReadMcpServers())) },
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
        FinishTurn(Session.CurrentTurn, Session.CurrentTurn.Status === "cancelling" ? "cancelled" : "error", Error.message);
      }

      console.error(`Session ${Session.Key} ended: ${Error.message}`);
    }

    Session.CurrentTurn = null;
    Session.Close();
  };

  Run();

  return Session;
}

let Spare = null;

function TakeSpare(Model, Effort) {
  const Ready = Spare;

  if (!Ready || Ready.Ended || Ready.CurrentTurn || Ready.Model !== Model || (Ready.Effort || null) !== (Effort || null)) {
    return null;
  }

  Spare = null;
  return Ready;
}

let LastFolder = null;

export function LastUsedFolder() {
  return LastFolder;
}

// Warming a spare in the wrong folder is worse than not warming one, because
// a mismatched spare cannot be reused. Wait until a turn tells us the folder.
export function KeepSpareWarm() {
  if (!KeepSessionsWarm || Spare || !LastFolder) {
    return;
  }

  Spare = OpenSession(null, LastFolder, AutoTiers[0].model, AutoTiers[0].effort, true);
}

function EffortRank(Effort) {
  return EffortOrder.indexOf(Effort || "none");
}

export function UsableFolder(Folder) {
  if (typeof Folder !== "string" || Folder.trim() === "") {
    return null;
  }

  try {
    return fs.statSync(Folder).isDirectory() ? Folder : null;
  } catch {
    return null;
  }
}

function DescribePlace(Place) {
  if (!Place || typeof Place.name !== "string" || Place.name === "") {
    return null;
  }

  const Said = (!Place.placeId || !Place.universeId)
    ? `The open place is "${Place.name}". It has not been published, so it has no place id or universe id yet.`
    : `The open place is "${Place.name}", place id ${Place.placeId}, universe id ${Place.universeId}.`;

  return `<studio_place>\n${Said}\n</studio_place>`;
}

export function StartTurn({ Text, ConversationId, Images, Model, Effort, AskForTools, GuardTools, Escalate, ExtraPrompt, FastMode, Place, Folder }) {
  const Existing = ConversationId ? GetConversation(ConversationId) : null;
  const Auto = !Model || Model === "auto";

  if (Escalate && Auto) {
    RecordTurnOutcome(ConversationId, { Failed: true, Denied: false });
  }

  const Chosen = Auto
    ? ChooseModel(ConversationId, Text, Boolean(Images && Images.length) || Text.includes("<studio_context>"))
    : { model: Model, effort: Escalate ? NextEffort(Model, Effort) : (SupportsEffort(Model, Effort) ? Effort : null) };
  const Turn = {
    Id: `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`,
    ConversationId,
    Prompt: Text,
    Auto,
    Model: Chosen.model,
    Effort: Chosen.effort,
    AskForTools: AskForTools !== false,
    GuardTools: GuardTools === true,
    ExtraPrompt: ExtraPrompt !== false,
    FastMode: FastMode === true,
    WorkingDirectory: (Existing && UsableFolder(Existing.workingDirectory)) || UsableFolder(Folder),
    SessionId: ConversationId,
    Status: "running",
    CommittedText: "",
    PendingText: "",
    CommittedThinking: "",
    PendingThinking: "",
    Activity: [],
    Calls: [],
    Usage: { Input: 0, Output: 0, Cached: 0 },
    StartedAt: Date.now(),
    Milliseconds: 0,
    Cost: 0,
    ContextWindow: 0,
    ContextModel: null,
    Images: [],
    Delivered: {},
    Permissions: [],
    PermissionCount: 0,
    Error: null,
    Version: 0,
    Waiters: [],
  };

  Turns.set(Turn.Id, Turn);
  LastFolder = Turn.WorkingDirectory;

  const Warm = ConversationId ? Sessions.get(ConversationId) : TakeSpare(Chosen.model, Chosen.effort);
  const Reusable = Warm && !Warm.CurrentTurn && !Warm.Ended && EffortRank(Chosen.effort) <= EffortRank(Warm.Effort) && Warm.ExtraPrompt === Turn.ExtraPrompt && Warm.FastMode === Turn.FastMode && Warm.WorkingDirectory === Turn.WorkingDirectory;

  if (Warm && !Reusable) {
    Warm.Close();
  }

  if (Reusable) {
    Turn.Effort = Warm.Effort;
  }

  const Session = (Reusable ? Warm : null) || OpenSession(ConversationId, Turn.WorkingDirectory, Chosen.model, Turn.Effort, Turn.AskForTools, Turn.ExtraPrompt, Turn.FastMode);

  if (Session.Model !== Chosen.model && Session.Query) {
    Session.Model = Chosen.model;
    Session.Query.setModel(Chosen.model).catch(() => {});
  }

  if (!ConversationId) {
    setTimeout(KeepSpareWarm, 1000);
  }

  Turn.Session = Session;
  Session.AskForTools = Turn.AskForTools;
  Session.GuardTools = Turn.GuardTools;
  Session.CurrentTurn = Turn;
  Session.LastUsedAt = Date.now();

  const Described = DescribePlace(Place);

  if (Described && Described !== Session.Place) {
    Session.Place = Described;
    Session.Send(UserMessage(`${Described}\n\n${Text}`, Images));

    return Turn;
  }

  Session.Send(UserMessage(Text, Images));

  return Turn;
}

export function GetTurn(Id) {
  return Turns.get(Id);
}

export function CancelTurn(Turn) {
  if (Turn.Status !== "running") {
    return;
  }

  Publish(Turn, { Status: "cancelling" });
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

export function ReleaseImage(Turn, Index) {
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

export function WaitForChange(Turn, KnownVersion, Milliseconds) {
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
      Resolve();
    }, Milliseconds);

    Turn.Waiters.push(Waiter);
  });
}

function Settle(Turn) {
  if (Turn.Status !== "running") {
    return Promise.resolve();
  }

  return new Promise((Resolve) => {
    setTimeout(Resolve, CoalesceMilliseconds);
  });
}

export function DescribeTurn(Turn) {
  return {
    requestId: Turn.Id,
    conversationId: Turn.ConversationId,
    sessionId: Turn.SessionId,
    status: Turn.Status === "cancelling" ? "running" : Turn.Status,
    text: JoinText(Turn.CommittedText, Turn.PendingText),
    thinking: JoinText(Turn.CommittedThinking, Turn.PendingThinking),
    activity: Turn.Activity,
    model: Turn.Model,
    effort: Turn.Effort,
    auto: Turn.Auto,
    imageCount: Turn.Images.length,
    permission: Turn.Permissions.length > 0
      ? { id: Turn.Permissions[0].Id, tool: Turn.Permissions[0].ToolName, input: JSON.stringify(Turn.Permissions[0].Input).slice(0, 600) }
      : null,
    error: Turn.Error,
    calls: Turn.Calls.map((Call) => ({
      name: Call.Name,
      input: Call.Input,
      output: Call.Output,
      status: Call.Status,
      steps: Call.Steps || [],
      milliseconds: Call.Milliseconds,
    })),
    milliseconds: Turn.Milliseconds || (Turn.Status === "running" ? Date.now() - Turn.StartedAt : 0),
    tokens: { input: Turn.Usage.Input, output: Turn.Usage.Output, cached: Turn.Usage.Cached },
    limits: GetLimits(),
    context: (Turn.Session && Turn.Session.Breakdown) || null,
    contextWindow: Turn.ContextWindow || 0,
    contextModel: Turn.ContextModel || null,
    cost: Turn.Cost,
    version: Turn.Version,
  };
}

export async function ForkConversation(ConversationId) {
  const Result = await forkSession(ConversationId);

  return Result.sessionId;
}
