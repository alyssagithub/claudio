import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { ChaptersFile, CostsFile, DesktopSessionsRoot, OwnSessionsFile, PriceFor, SessionsRoot } from "./Config.js";
import { DecodeImage, ImagesInContent } from "./Images.js";

function FindFile(Id) {
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

function ReadJson(File) {
  try {
    return JSON.parse(fs.readFileSync(File, "utf8"));
  } catch {
    return null;
  }
}

function ReadDesktopSessions() {
  const Sessions = {};

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

        const Session = ReadJson(path.join(Folder, Name));

        if (!Session || !Session.cliSessionId) {
          continue;
        }

        Sessions[Session.cliSessionId] = { title: Session.title, workingDirectory: Session.cwd, starred: Session.isStarred === true, archived: Session.isArchived === true };
      }
    }
  }

  return Sessions;
}

function DesktopSessionsFolder() {
  if (!fs.existsSync(DesktopSessionsRoot)) {
    return null;
  }

  let Newest = null;

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

export function AddDesktopSession(Id, WorkingDirectory, Title) {
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

function DesktopSessionFiles() {
  const Files = [];

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

export function UpdateDesktopSession(Id, Change) {
  for (const File of DesktopSessionFiles()) {
    const Session = ReadJson(File);

    if (!Session || Session.cliSessionId !== Id) {
      continue;
    }

    Change(Session);
    fs.writeFileSync(File, JSON.stringify(Session, null, 2));
    return;
  }
}

function ReadOwnSessions() {
  const Stored = ReadJson(OwnSessionsFile) || [];

  if (Array.isArray(Stored)) {
    return new Map(Stored.map((Id) => [Id, false]));
  }

  return new Map(Object.entries(Stored));
}

function WriteOwnSessions(Own) {
  fs.mkdirSync(path.dirname(OwnSessionsFile), { recursive: true });
  fs.writeFileSync(OwnSessionsFile, JSON.stringify(Object.fromEntries(Own), null, 2));
}

export function RememberOwnSession(Id) {
  const Own = ReadOwnSessions();

  if (Own.has(Id)) {
    return;
  }

  Own.set(Id, false);
  WriteOwnSessions(Own);
}

function TextOf(Content) {
  if (typeof Content === "string") {
    return Content;
  }

  return (Content || []).filter((Block) => Block.type === "text").map((Block) => Block.text).join("");
}

export function StripContext(Text) {
  return Text
    .replace(/\n*<studio_context>[\s\S]*?<\/studio_context>\n*/g, "")
    .replace(/\n*<studio_place>[\s\S]*?<\/studio_place>\n*/g, "")
    .replace(/\n*<studio_edits>[\s\S]*?<\/studio_edits>\n*/g, "")
    .trim();
}

function IsPromptLine(Line) {
  return Line.type === "user"
    && !Line.isMeta
    && !Line.isSidechain
    && Line.message
    && (typeof Line.message.content === "string" || (Line.message.content || []).some((Block) => Block.type === "text"))
    && !StripContext(TextOf(Line.message.content)).startsWith("<");
}

const Parsed = new Map();

// Claude Code can be killed mid-write, leaving a line with no newline after
// it. Appending to that joins two records into one and both readers lose it.
function EndsCleanly(File) {
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

// A rename is appended, so the newest title lives at the end of a file the
// head read never reaches. Only title lines matter here.
function ReadTail(File) {
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
        return JSON.parse(Line);
      } catch {
        return null;
      }
    }).filter((Line) => Line && Line.type === "custom-title");
  } catch {
    return [];
  }
}

function ReadLines(File, MaxBytes) {
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
      Parsed.delete(Parsed.keys().next().value);
    }

    Parsed.set(Key, { Stamp, Lines });
  }

  return Lines;
}

function ParseLines(File, MaxBytes) {
  try {
    const Descriptor = fs.openSync(File, "r");
    const Size = fs.fstatSync(Descriptor).size;
    const Buffer = new Uint8Array(Math.min(Size, MaxBytes || Size));

    fs.readSync(Descriptor, Buffer, 0, Buffer.length, 0);
    fs.closeSync(Descriptor);

    return new TextDecoder().decode(Buffer).split("\n").map((Raw) => {
      try {
        return JSON.parse(Raw);
      } catch {
        return null;
      }
    }).filter(Boolean);
  } catch {
    return null;
  }
}

function TitleOf(Lines, Desktop, IsOwn) {
  const Named = Lines.find((Line) => Line.type === "custom-title" && Line.customTitle)
    || Lines.find((Line) => Line.type === "ai-title" && Line.aiTitle)
    || Lines.find((Line) => Line.type === "summary" && Line.summary);

  if (Desktop && Desktop.title && !(IsOwn && Named)) {
    return Desktop.title;
  }

  if (Named) {
    return Named.customTitle || Named.aiTitle || Named.summary;
  }

  const Prompt = Lines.find(IsPromptLine);

  return Prompt ? StripContext(TextOf(Prompt.message.content)).replace(/\s+/g, " ").trim().slice(0, 60) : "New chat";
}

function WorkingDirectoryOf(Lines) {
  const Line = Lines.find((Entry) => typeof Entry.cwd === "string" && Entry.cwd !== "");

  return Line ? Line.cwd : null;
}

export function ListConversations() {
  if (!fs.existsSync(SessionsRoot)) {
    return [];
  }

  const Desktop = ReadDesktopSessions();
  const Own = ReadOwnSessions();
  const Deletable = DesktopSessionsFolder() !== null && Object.keys(Desktop).length > 0;
  const Summaries = [];

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
      const Lines = ReadLines(File).concat(ReadTail(File));

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
        source: Desktop[Id] ? "desktop" : "claudio",
        starred: Boolean(Desktop[Id] && Desktop[Id].starred),
        archived: Boolean(Desktop[Id] && Desktop[Id].archived),
        updatedAt: fs.statSync(File).mtimeMs,
      });
    }
  }

  return Summaries.sort((Left, Right) => (Number(Right.starred) - Number(Left.starred)) || (Right.updatedAt - Left.updatedAt));
}

export function GetConversationImage(Id, Wanted) {
  const File = FindFile(Id);
  const Lines = File ? ReadLines(File) : null;
  let Index = 0;

  for (const Line of Lines || []) {
    if (Line.isSidechain || Line.type !== "user" || !Line.message) {
      continue;
    }

    for (const Image of ImagesInContent(Line.message.content)) {
      Index += 1;

      if (Index === Wanted) {
        return DecodeImage(Image.mediaType, Image.data);
      }
    }
  }

  return null;
}

function ReadCosts() {
  return ReadJson(CostsFile) || {};
}

export function ForgetCosts(Id) {
  const Costs = ReadCosts();

  if (!Costs[Id]) {
    return;
  }

  delete Costs[Id];
  fs.writeFileSync(CostsFile, JSON.stringify(Costs, null, 2));
}

function CostList(Stored) {
  if (Array.isArray(Stored)) {
    return Stored;
  }

  return Object.keys(Stored || {}).sort((Left, Right) => Number(Left) - Number(Right)).map((Key) => Stored[Key]);
}

export function RecordCost(Id, Cost) {
  if (!Id || !Cost) {
    return;
  }

  const Costs = ReadCosts();

  Costs[Id] = CostList(Costs[Id]).concat(Cost);
  fs.mkdirSync(path.dirname(CostsFile), { recursive: true });
  fs.writeFileSync(CostsFile, JSON.stringify(Costs, null, 2));
}

function EstimateCost(Line) {
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

function UsageOf(Line) {
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

function TimeOf(Line) {
  const Stamp = Date.parse(Line.timestamp || "");

  return Number.isNaN(Stamp) ? null : Math.floor(Stamp / 1000);
}

export function ConversationExists(Id) {
  return FindFile(Id) !== null;
}

export function GetConversation(Id) {
  const File = FindFile(Id);
  const Lines = File ? ReadLines(File) : null;

  if (!Lines) {
    return null;
  }

  const Messages = [];
  let PendingTools = [];
  let PendingImages = [];
  let ImageIndex = 0;
  const Priced = new Set();
  let PendingCost = 0;

  for (const Line of Lines) {
    if (Line.isSidechain || !Line.message) {
      continue;
    }

    if (IsPromptLine(Line)) {
      const Attached = [];

      for (const Image of ImagesInContent(Line.message.content)) {
        ImageIndex += 1;
        Attached.push(ImageIndex);
      }

      Messages.push({ role: "user", text: StripContext(TextOf(Line.message.content)), images: Attached, at: TimeOf(Line) });
      PendingTools = [];
      PendingImages = [];
    } else if (Line.type === "user") {
      for (const Image of ImagesInContent(Line.message.content)) {
        ImageIndex += 1;
        PendingImages.push(ImageIndex);
      }
    } else if (Line.type === "assistant") {
      const Content = Line.message.content || [];
      const Text = TextOf(Content);
      const Response = Line.requestId || (Line.message && Line.message.id);

      if (Response === undefined || !Priced.has(Response)) {
        Priced.add(Response);
        PendingCost += EstimateCost(Line) || 0;
      }

      PendingTools = PendingTools.concat(Content.filter((Block) => Block.type === "tool_use").map((Block) => Block.name));

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

      if (Last && Last.role === "assistant") {
        Last.text = `${Last.text}\n\n${Text}`;
        Last.activity = Last.activity.concat(PendingTools);
        Last.images = Last.images.concat(PendingImages);
        Last.tokens = Used || Last.tokens;
        Last.cost = (Last.cost || 0) + (Spent || 0);
      } else {
        Messages.push({ role: "assistant", text: Text, activity: PendingTools, images: PendingImages, at: TimeOf(Line), tokens: Used, cost: Spent, estimated: true });
      }

      PendingTools = [];
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

function ReadChapters() {
  return ReadJson(ChaptersFile) || {};
}

export function GetChapters(Id) {
  return ReadChapters()[Id] || [];
}

export function SetChapters(Id, Chapters) {
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

export function RenameConversation(Id, Title) {
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

export function SetConversationFlag(Id, Field, Value) {
  let Changed = false;

  UpdateDesktopSession(Id, (Session) => {
    Session[Field] = Value;
    Changed = true;
  });

  return Changed;
}

function RemoveDesktopSession(Id) {
  const Folder = DesktopSessionsFolder();

  if (!Folder) {
    return;
  }

  for (const Name of fs.readdirSync(Folder)) {
    if (!Name.endsWith(".json")) {
      continue;
    }

    const File = path.join(Folder, Name);
    const Session = ReadJson(File);

    if (Session && Session.cliSessionId === Id) {
      fs.rmSync(File, { force: true });
      return;
    }
  }
}

function ForgetOwnSession(Id) {
  const Own = ReadOwnSessions();

  if (!Own.delete(Id)) {
    return;
  }

  WriteOwnSessions(Own);
}

export function DeleteConversation(Id) {
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
