import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { ChaptersFile, CostsFile, DesktopSessionsRoot, HiddenFoldersFile, OwnSessionsFile, PriceFor, SessionsRoot } from "./Config.js";
import { DecodeImage, ImagesInContent } from "./Images.js";
import type { Chapter, Content, ContentBlock, StoredCall, StoredMessage, Tokens, TranscriptLine } from "./Types.js";

type TranscriptEntry = TranscriptLine & { customTitle?: string; aiTitle?: string; summary?: string };

type DesktopSession = { title: string | undefined; workingDirectory: string | undefined; starred: boolean; archived: boolean };

type DesktopRecord = Record<string, unknown> & { cliSessionId?: string; title?: string; cwd?: string; isStarred?: boolean; isArchived?: boolean };

type CostStore = Record<string, number[] | Record<string, number>>;

type Listing = { id: string; title: string; project: string; folder: string | null; source: string; starred: boolean; archived: boolean; hidden: boolean; createdAt: number; updatedAt: number };

function FindFile(Id: string): string | null {
  if (!fs.existsSync(SessionsRoot)) {
    return null;
  }

  for (const Project of fs.readdirSync(SessionsRoot)) {
    const Candidate = path.join(SessionsRoot, Project, `${Id}.jsonl`);

    if (fs.existsSync(Candidate)) {
      return Candidate;
    }
  }

  return null;
}

function ReadJson<Value>(File: string): Value | null {
  try {
    return JSON.parse(fs.readFileSync(File, "utf8")) as Value;
  } catch {
    return null;
  }
}

function ReadDesktopSessions(): Record<string, DesktopSession> {
  const Sessions: Record<string, DesktopSession> = {};

  if (!fs.existsSync(DesktopSessionsRoot)) {
    return Sessions;
  }

  for (const Account of fs.readdirSync(DesktopSessionsRoot)) {
    const AccountFolder = path.join(DesktopSessionsRoot, Account);

    if (!fs.statSync(AccountFolder).isDirectory()) {
      continue;
    }

    for (const Organization of fs.readdirSync(AccountFolder)) {
      const Folder = path.join(AccountFolder, Organization);

      if (!fs.statSync(Folder).isDirectory()) {
        continue;
      }

      for (const Name of fs.readdirSync(Folder)) {
        if (!Name.startsWith("local_") || !Name.endsWith(".json")) {
          continue;
        }

        const Session = ReadJson<DesktopRecord>(path.join(Folder, Name));

        if (!Session || !Session.cliSessionId) {
          continue;
        }

        Sessions[Session.cliSessionId] = { title: Session.title, workingDirectory: Session.cwd, starred: Session.isStarred === true, archived: Session.isArchived === true };
      }
    }
  }

  return Sessions;
}

function DesktopSessionsFolder(): string | null {
  if (!fs.existsSync(DesktopSessionsRoot)) {
    return null;
  }

  let Newest: { Folder: string; mtimeMs: number } | null = null;

  for (const Account of fs.readdirSync(DesktopSessionsRoot)) {
    const AccountFolder = path.join(DesktopSessionsRoot, Account);

    if (!fs.statSync(AccountFolder).isDirectory()) {
      continue;
    }

    for (const Organization of fs.readdirSync(AccountFolder)) {
      const Folder = path.join(AccountFolder, Organization);
      const Stat = fs.statSync(Folder);

      if (Stat.isDirectory() && (!Newest || Stat.mtimeMs > Newest.mtimeMs)) {
        Newest = { Folder, mtimeMs: Stat.mtimeMs };
      }
    }
  }

  return Newest ? Newest.Folder : null;
}

export function AddDesktopSession(Id: string, WorkingDirectory: string, Title: string) {
  const Folder = DesktopSessionsFolder();

  if (!Folder || ReadDesktopSessions()[Id]) {
    return;
  }

  const CurrentTime = Date.now();
  const Session = {
    sessionId: `local_${crypto.randomUUID()}`,
    cliSessionId: Id,
    cwd: WorkingDirectory,
    originCwd: WorkingDirectory,
    lastFocusedAt: CurrentTime,
    createdAt: CurrentTime,
    lastActivityAt: CurrentTime,
    model: "claude-opus-5",
    effort: "low",
    isArchived: false,
    title: Title,
    titleSource: "user",
    permissionMode: "default",
    completedTurns: 0,
    lastSpawnRootDetected: false,
    remoteControlAutoEligible: false,
    alwaysAllowedReasons: [],
    sessionPermissionUpdates: [],
    classifierSummaryEnabled: false,
    reportFindingsCard: true,
    spawnSeed: {},
  };

  fs.writeFileSync(path.join(Folder, `${Session.sessionId}.json`), JSON.stringify(Session, null, 2));
}

function DesktopSessionFiles(): string[] {
  const Files: string[] = [];

  if (!fs.existsSync(DesktopSessionsRoot)) {
    return Files;
  }

  for (const Account of fs.readdirSync(DesktopSessionsRoot)) {
    const AccountFolder = path.join(DesktopSessionsRoot, Account);

    if (!fs.statSync(AccountFolder).isDirectory()) {
      continue;
    }

    for (const Organization of fs.readdirSync(AccountFolder)) {
      const Folder = path.join(AccountFolder, Organization);

      if (!fs.statSync(Folder).isDirectory()) {
        continue;
      }

      for (const Name of fs.readdirSync(Folder)) {
        if (Name.startsWith("local_") && Name.endsWith(".json")) {
          Files.push(path.join(Folder, Name));
        }
      }
    }
  }

  return Files;
}

export function UpdateDesktopSession(Id: string, Change: (Session: DesktopRecord) => void) {
  for (const File of DesktopSessionFiles()) {
    const Session = ReadJson<DesktopRecord>(File);

    if (!Session || Session.cliSessionId !== Id) {
      continue;
    }

    Change(Session);
    fs.writeFileSync(File, JSON.stringify(Session, null, 2));
    return;
  }
}

function ReadOwnSessions(): Map<string, boolean> {
  const Stored = ReadJson<string[] | Record<string, boolean>>(OwnSessionsFile) || [];

  if (Array.isArray(Stored)) {
    return new Map(Stored.map((Id) => [Id, false] as [string, boolean]));
  }

  return new Map(Object.entries(Stored));
}

function WriteOwnSessions(Own: Map<string, boolean>) {
  fs.mkdirSync(path.dirname(OwnSessionsFile), { recursive: true });
  fs.writeFileSync(OwnSessionsFile, JSON.stringify(Object.fromEntries(Own), null, 2));
}

export function RememberOwnSession(Id: string) {
  const Own = ReadOwnSessions();

  if (Own.has(Id)) {
    return;
  }

  Own.set(Id, false);
  WriteOwnSessions(Own);
}

function InputOf(Input: unknown): string {
  if (!Input || typeof Input !== "object" || Array.isArray(Input)) {
    return String(Input === undefined ? "" : Input);
  }

  return Object.entries(Input)
    .map(([Name, Value]) => `${Name}: ${typeof Value === "string" ? Value : JSON.stringify(Value)}`)
    .join("\n")
    .slice(0, 4000);
}

function TextOf(Content: Content | undefined): string {
  if (typeof Content === "string") {
    return Content;
  }

  return (Content || []).filter((Block) => Block.type === "text").map((Block) => Block.text).join("");
}

const ContextPattern = /<studio_context>[\s\S]*?<\/studio_context>|<studio_place>[\s\S]*?<\/studio_place>|<studio_edits>[\s\S]*?<\/studio_edits>|<studio_lint>[\s\S]*?<\/studio_lint>|I changed these in Studio myself since my last message:(?:\n- [^\n]*)+/g;

export function ExtractContext(Text: string): string {
  return (Text.match(ContextPattern) || []).join("\n\n");
}

export function StripContext(Text: string): string {
  return Text
    .replace(/\n*<studio_context>[\s\S]*?<\/studio_context>\n*/g, "")
    .replace(/\n*<studio_place>[\s\S]*?<\/studio_place>\n*/g, "")
    .replace(/\n*<studio_edits>[\s\S]*?<\/studio_edits>\n*/g, "")
    .replace(/\n*<studio_lint>[\s\S]*?<\/studio_lint>\n*/g, "")
    .replace(/\n*I changed these in Studio myself since my last message:(?:\n- [^\n]*)+\n*/g, "")
    .trim();
}

function IsPromptLine(Line: TranscriptEntry) {
  return Line.type === "user"
    && !Line.isMeta
    && !Line.isSidechain
    && Line.message
    && (typeof Line.message.content === "string" || (Line.message.content || []).some((Block) => Block.type === "text"))
    && !StripContext(TextOf(Line.message.content)).startsWith("<");
}

const Parsed = new Map<string, { Stamp: string; Lines: TranscriptEntry[] }>();

function EndsCleanly(File: string): boolean {
  try {
    const Size = fs.statSync(File).size;

    if (Size === 0) {
      return true;
    }

    const Handle = fs.openSync(File, "r");
    const Last = global.Buffer.alloc(1);

    fs.readSync(Handle, Last, 0, 1, Size - 1);
    fs.closeSync(Handle);

    return Last.toString("utf8") === "\n";
  } catch {
    return true;
  }
}

function ReadTail(File: string): TranscriptEntry[] {
  try {
    const Size = fs.statSync(File).size;

    if (Size <= 256 * 1024) {
      return [];
    }

    const Handle = fs.openSync(File, "r");
    const Length = Math.min(64 * 1024, Size);
    const Buffer = global.Buffer.alloc(Length);

    fs.readSync(Handle, Buffer, 0, Length, Size - Length);
    fs.closeSync(Handle);

    return Buffer.toString("utf8").split("\n").map((Line) => {
      try {
        return JSON.parse(Line) as TranscriptEntry;
      } catch {
        return null;
      }
    }).filter((Line) => Line && Line.type === "custom-title") as TranscriptEntry[];
  } catch {
    return [];
  }
}

function ReadLines(File: string, MaxBytes?: number): TranscriptEntry[] | null {
  const Key = `${File}:${MaxBytes || 0}`;
  const Stamp = (() => {
    try {
      const Stat = fs.statSync(File);

      return `${Stat.mtimeMs}:${Stat.size}`;
    } catch {
      return null;
    }
  })();
  const Remembered = Parsed.get(Key);

  if (Remembered && Stamp && Remembered.Stamp === Stamp) {
    return Remembered.Lines;
  }

  const Lines = ParseLines(File, MaxBytes);

  if (Lines && Stamp) {
    if (Parsed.size >= 4) {
      Parsed.delete(Parsed.keys().next().value as string);
    }

    Parsed.set(Key, { Stamp, Lines });
  }

  return Lines;
}

function ParseLines(File: string, MaxBytes?: number): TranscriptEntry[] | null {
  try {
    const Descriptor = fs.openSync(File, "r");
    const Size = fs.fstatSync(Descriptor).size;
    const Buffer = new Uint8Array(Math.min(Size, MaxBytes || Size));

    fs.readSync(Descriptor, Buffer, 0, Buffer.length, 0);
    fs.closeSync(Descriptor);

    return new TextDecoder().decode(Buffer).split("\n").map((Raw) => {
      try {
        return JSON.parse(Raw) as TranscriptEntry;
      } catch {
        return null;
      }
    }).filter(Boolean) as TranscriptEntry[];
  } catch {
    return null;
  }
}

function TitleOf(Lines: TranscriptEntry[], Desktop: DesktopSession | undefined, IsOwn: boolean): string {
  const Named = Lines.find((Line) => Line.type === "custom-title" && Line.customTitle)
    || Lines.find((Line) => Line.type === "ai-title" && Line.aiTitle)
    || Lines.find((Line) => Line.type === "summary" && Line.summary);

  if (Desktop && Desktop.title && !(IsOwn && Named)) {
    return Desktop.title;
  }

  if (Named) {
    return (Named.customTitle || Named.aiTitle || Named.summary) as string;
  }

  const Prompt = Lines.find(IsPromptLine);

  return Prompt ? StripContext(TextOf(Prompt.message!.content)).replace(/\s+/g, " ").trim().slice(0, 60) : "New chat";
}

function StampOf(Entry: TranscriptEntry | undefined): number {
  return Entry && typeof Entry.timestamp === "string" ? Date.parse(Entry.timestamp) : NaN;
}

function StartedAt(Lines: TranscriptEntry[], File: string): number {
  for (const Entry of Lines) {
    if (Number.isFinite(StampOf(Entry))) {
      return StampOf(Entry);
    }
  }

  return fs.statSync(File).birthtimeMs;
}

function EndedAt(Lines: TranscriptEntry[], File: string): number {
  for (let Index = Lines.length - 1; Index >= 0; Index -= 1) {
    if (Number.isFinite(StampOf(Lines[Index]))) {
      return StampOf(Lines[Index]);
    }
  }

  return fs.statSync(File).mtimeMs;
}

function WorkingDirectoryOf(Lines: TranscriptEntry[]): string | null {
  const Line = Lines.find((Entry) => typeof Entry.cwd === "string" && Entry.cwd !== "");

  return Line ? Line.cwd as string : null;
}

function SameFolder(Left: string, Right: string): boolean {
  return path.resolve(Left).toLowerCase() === path.resolve(Right).toLowerCase();
}

export function ReadHiddenFolders(): string[] {
  const Stored = ReadJson<unknown>(HiddenFoldersFile);

  return Array.isArray(Stored) ? Stored.filter((Entry): Entry is string => typeof Entry === "string") : [];
}

export function SetFolderHidden(Folder: string, Hidden: boolean) {
  const Kept = ReadHiddenFolders().filter((Entry) => !SameFolder(Entry, Folder));

  if (Hidden) {
    Kept.push(Folder);
  }

  fs.mkdirSync(path.dirname(HiddenFoldersFile), { recursive: true });
  fs.writeFileSync(HiddenFoldersFile, JSON.stringify(Kept, null, 2));
}

export function ListConversations(): Listing[] {
  if (!fs.existsSync(SessionsRoot)) {
    return [];
  }

  const Desktop = ReadDesktopSessions();
  const Own = ReadOwnSessions();
  const Hidden = ReadHiddenFolders();
  const Deletable = DesktopSessionsFolder() !== null && Object.keys(Desktop).length > 0;
  const Summaries: Listing[] = [];

  for (const Project of fs.readdirSync(SessionsRoot)) {
    const Folder = path.join(SessionsRoot, Project);

    if (!fs.statSync(Folder).isDirectory()) {
      continue;
    }

    for (const Name of fs.readdirSync(Folder)) {
      const Id = Name.slice(0, -6);

      if (!Name.endsWith(".jsonl") || (!Desktop[Id] && !Own.has(Id))) {
        continue;
      }

      const File = path.join(Folder, Name);
      const Lines = ReadLines(File)!.concat(ReadTail(File));

      if (!Lines || !Lines.some(IsPromptLine)) {
        continue;
      }

      const WorkingDirectory = WorkingDirectoryOf(Lines);

      const Title = TitleOf(Lines, Desktop[Id], Own.has(Id));

      if (Desktop[Id] && Desktop[Id].title !== Title) {
        UpdateDesktopSession(Id, (Session) => {
          Session.title = Title;
        });
      }

      Summaries.push({
        id: Id,
        title: Title,
        project: WorkingDirectory ? path.basename(WorkingDirectory) : Project,
        folder: WorkingDirectory || null,
        source: Desktop[Id] ? "desktop" : "claudio",
        starred: Boolean(Desktop[Id] && Desktop[Id].starred),
        archived: Boolean(Desktop[Id] && Desktop[Id].archived),
        hidden: WorkingDirectory !== null && Hidden.some((Entry) => SameFolder(Entry, WorkingDirectory)),
        createdAt: StartedAt(Lines, File),
        updatedAt: EndedAt(Lines, File),
      });
    }
  }

  return Summaries.sort((Left, Right) => (Number(Right.starred) - Number(Left.starred)) || (Right.updatedAt - Left.updatedAt));
}

export function GetConversationImage(Id: string, Wanted: number) {
  const File = FindFile(Id);
  const Lines = File ? ReadLines(File) : null;
  let Index = 0;

  for (const Line of Lines || []) {
    if (Line.isSidechain || Line.type !== "user" || !Line.message) {
      continue;
    }

    for (const Image of ImagesInContent(Line.message!.content)) {
      Index += 1;

      if (Index === Wanted) {
        return DecodeImage(Image.mediaType, Image.data);
      }
    }
  }

  return null;
}

function ReadCosts(): CostStore {
  return ReadJson<CostStore>(CostsFile) || {};
}

export function ForgetCosts(Id: string) {
  const Costs = ReadCosts();

  if (!Costs[Id]) {
    return;
  }

  delete Costs[Id];
  fs.writeFileSync(CostsFile, JSON.stringify(Costs, null, 2));
}

function CostList(Stored: number[] | Record<string, number> | undefined): number[] {
  if (Array.isArray(Stored)) {
    return Stored;
  }

  return Object.keys(Stored || {}).sort((Left, Right) => Number(Left) - Number(Right)).map((Key) => (Stored as Record<string, number>)[Key]);
}

export function RecordCost(Id: string, Cost: number) {
  if (!Id || !Cost) {
    return;
  }

  const Costs = ReadCosts();

  Costs[Id] = CostList(Costs[Id]).concat(Cost);
  fs.mkdirSync(path.dirname(CostsFile), { recursive: true });
  fs.writeFileSync(CostsFile, JSON.stringify(Costs, null, 2));
}

function EstimateCost(Line: TranscriptEntry): number | null {
  const Usage = Line.message && Line.message.usage;
  const Price = PriceFor((Line.message && Line.message.model) || "");

  if (!Usage || !Price) {
    return null;
  }

  return (
    (Usage.input_tokens || 0) * Price.input
    + (Usage.cache_creation_input_tokens || 0) * Price.input * 2
    + (Usage.cache_read_input_tokens || 0) * Price.input * 0.1
    + (Usage.output_tokens || 0) * Price.output
  ) / 1000000;
}

function UsageOf(Line: TranscriptEntry): Tokens | null {
  const Usage = Line.message && Line.message.usage;

  if (!Usage) {
    return null;
  }

  return {
    input: (Usage.input_tokens || 0) + (Usage.cache_creation_input_tokens || 0),
    output: Usage.output_tokens || 0,
    cached: Usage.cache_read_input_tokens || 0,
  };
}

function TimeOf(Line: TranscriptEntry): number | null {
  const Stamp = Date.parse(Line.timestamp || "");

  return Number.isNaN(Stamp) ? null : Math.floor(Stamp / 1000);
}

export function ConversationExists(Id: string): boolean {
  return FindFile(Id) !== null;
}

export function GetConversation(Id: string) {
  const File = FindFile(Id);
  const Lines = File ? ReadLines(File) : null;

  if (!Lines) {
    return null;
  }

  const Messages: StoredMessage[] = [];
  let PendingTools: string[] = [];
  let PendingCalls: { Id: string; name: string; input: string }[] = [];
  const Results = new Map<string, { Output: string; Failed: boolean; Image: number | null }>();
  let PendingImages: number[] = [];
  let ImageIndex = 0;
  const Priced = new Set<string | undefined>();
  let PendingCost = 0;

  for (const Line of Lines) {
    if (Line.isSidechain || !Line.message) {
      continue;
    }

    if (IsPromptLine(Line)) {
      const Attached: number[] = [];

      for (const Image of ImagesInContent(Line.message.content)) {
        ImageIndex += 1;
        Attached.push(ImageIndex);
      }

      Messages.push({ role: "user", text: StripContext(TextOf(Line.message.content)), images: Attached, at: TimeOf(Line) });
      PendingTools = [];
      PendingCalls = [];
      PendingImages = [];
    } else if (Line.type === "user") {
      for (const Block of (Line.message.content || []) as ContentBlock[]) {
        const Pictures = ImagesInContent([Block]).length;

        if (Block.type === "tool_result") {
          Results.set(Block.tool_use_id as string, { Output: TextOf(Block.content).slice(0, 2000), Failed: Block.is_error === true, Image: Pictures > 0 ? PendingImages.length + 1 : null });
        }

        for (let Count = 0; Count < Pictures; Count += 1) {
          ImageIndex += 1;
          PendingImages.push(ImageIndex);
        }
      }
    } else if (Line.type === "assistant") {
      const Content = (Line.message.content || []) as ContentBlock[];
      const Text = TextOf(Content);
      const Response = Line.requestId || (Line.message && Line.message.id);

      if (Response === undefined || !Priced.has(Response)) {
        Priced.add(Response);
        PendingCost += EstimateCost(Line) || 0;
      }

      PendingTools = PendingTools.concat(Content.filter((Block) => Block.type === "tool_use").map((Block) => Block.name as string));
      PendingCalls = PendingCalls.concat(Content.filter((Block) => Block.type === "tool_use").map((Block) => ({ Id: Block.id as string, name: Block.name as string, input: InputOf(Block.input) })));

      if (Text === "") {
        continue;
      }

      const Last = Messages[Messages.length - 1];
      const Used = UsageOf(Line);
      const Spent = PendingCost;

      PendingCost = 0;

      for (let At = Messages.length - 1; At >= 0 && Used; At -= 1) {
        if (Messages[At].role === "user") {
          Messages[At].tokens = Used;
          break;
        }
      }

      const Before = Last && Last.role === "assistant" ? Last.images.length : 0;
      const Calls: StoredCall[] = PendingCalls.map((Call) => {
        const Result = Results.get(Call.Id);

        return { name: Call.name, input: Call.input, output: Result ? Result.Output : "", status: Result && Result.Failed ? "error" : "done", milliseconds: 0, image: Result && Result.Image ? Result.Image + Before : null };
      });

      if (Last && Last.role === "assistant") {
        Last.text = `${Last.text}\n\n${Text}`;
        Last.activity = Last.activity!.concat(PendingTools);
        Last.calls = Last.calls!.concat(Calls);
        Last.images = Last.images.concat(PendingImages);
        Last.tokens = Used || Last.tokens;
        Last.cost = (Last.cost || 0) + (Spent || 0);
      } else {
        Messages.push({ role: "assistant", text: Text, activity: PendingTools, calls: Calls, images: PendingImages, at: TimeOf(Line), tokens: Used, cost: Spent, estimated: true });
      }

      PendingTools = [];
      PendingCalls = [];
      PendingImages = [];
    }
  }

  const Recorded = CostList(ReadCosts()[Id]);
  let Reply = 0;

  for (const Message of Messages) {
    if (Message.role !== "assistant") {
      continue;
    }

    Reply += 1;

    if (Recorded[Reply - 1]) {
      Message.cost = Recorded[Reply - 1];
      Message.estimated = false;
    }
  }

  const Trailing = Messages[Messages.length - 1];

  if (Trailing && Trailing.role === "assistant" && PendingImages.length > 0) {
    Trailing.images = Trailing.images.concat(PendingImages);
  }

  const Desktop = ReadDesktopSessions()[Id];
  const WorkingDirectory = WorkingDirectoryOf(Lines);

  return {
    id: Id,
    title: TitleOf(Lines, Desktop, ReadOwnSessions().has(Id)),
    project: WorkingDirectory ? path.basename(WorkingDirectory) : null,
    source: Desktop ? "desktop" : "claudio",
    workingDirectory: WorkingDirectory,
    messages: Messages,
  };
}

function ReadChapters(): Record<string, Chapter[]> {
  return ReadJson<Record<string, Chapter[]>>(ChaptersFile) || {};
}

export function GetChapters(Id: string): Chapter[] {
  return ReadChapters()[Id] || [];
}

export function SetChapters(Id: string, Chapters: Chapter[]): Chapter[] {
  const All = ReadChapters();

  if (Chapters.length === 0) {
    delete All[Id];
  } else {
    All[Id] = Chapters;
  }

  fs.mkdirSync(path.dirname(ChaptersFile), { recursive: true });
  fs.writeFileSync(ChaptersFile, JSON.stringify(All, null, 2));
  return Chapters;
}

export function RenameConversation(Id: string, Title: string): boolean {
  const File = FindFile(Id);

  if (!File) {
    return false;
  }

  fs.appendFileSync(File, `${EndsCleanly(File) ? "" : "\n"}${JSON.stringify({ type: "custom-title", customTitle: Title, timestamp: new Date().toISOString() })}\n`);
  UpdateDesktopSession(Id, (Session) => {
    Session.title = Title;
    Session.titleSource = "user";
  });

  return true;
}

export function SetConversationFlag(Id: string, Field: string, Value: unknown): boolean {
  let Changed = false;

  UpdateDesktopSession(Id, (Session) => {
    Session[Field] = Value;
    Changed = true;
  });

  return Changed;
}

function RemoveDesktopSession(Id: string) {
  const Folder = DesktopSessionsFolder();

  if (!Folder) {
    return;
  }

  for (const Name of fs.readdirSync(Folder)) {
    if (!Name.endsWith(".json")) {
      continue;
    }

    const File = path.join(Folder, Name);
    const Session = ReadJson<DesktopRecord>(File);

    if (Session && Session.cliSessionId === Id) {
      fs.rmSync(File, { force: true });
      return;
    }
  }
}

function ForgetOwnSession(Id: string) {
  const Own = ReadOwnSessions();

  if (!Own.delete(Id)) {
    return;
  }

  WriteOwnSessions(Own);
}

export function DeleteConversation(Id: string): boolean {
  const File = FindFile(Id);

  if (!File) {
    return false;
  }

  fs.rmSync(File, { force: true });
  fs.rmSync(File.slice(0, -6), { recursive: true, force: true });
  RemoveDesktopSession(Id);
  ForgetOwnSession(Id);
  ForgetCosts(Id);
  return true;
}