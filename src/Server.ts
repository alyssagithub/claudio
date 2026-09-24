import crypto from "node:crypto";
import http from "node:http";
import type { IncomingMessage, ServerResponse } from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { exec, execFile, spawn } from "node:child_process";
import { AunId, DefaultMode, LongPollMilliseconds, MaxBodyBytes, MostScriptsToCheck, ProtocolVersion, Version, WorkingDirectory } from "./Config.js";
import { SystemPromptFor } from "./Config.js";
import { GetLimits, GetBreakdown, PollUsage, RefreshConversationContext } from "./ClaudeSession.js";
import { Take as TakeStudioJob, Deliver as DeliverStudio, Request as RequestStudio, Presence as StudioPresence, Serving } from "./Studio.js";
import { StudioTools } from "./Tools.js";
import type { Reacher, ReacherIn } from "./Tools.js";
import type { Picture, TurnRequest } from "./Types.js";
import { StudioProcesses } from "./StudioPresence.js";
import { ActiveTurnFor, AddToTurn, ApplyStyleEverywhere, CloseConversation, LastEndedAt, LastUsedFolder, AbortAllTurns, AnswerPermission, AnswerQuestion, CancelTurn, DescribeTurn, DiscoverCommands, WarmConversation, ForkConversation, GetCommands, GetMcpServers, GetTurn, IsConversationBusy, KeepSpareWarm, ReadMcpServers, ReleaseImage, StartTurn, WaitForChange } from "./ClaudeSession.js";
import { ConversationExists, DeleteConversation, GetChapters, GetSubagent, GetConversation, GetConversationImage, ListConversations, RenameConversation, SetChapters, SetConversationFlag, SetFolderHidden } from "./Conversations.js";
import { DecodeImage } from "./Images.js";
import { AvatarFor } from "./EasterEgg.js";
import { HandToken, IssuePlaytestKey, PlaytestKeyMatches, PlaytestLive, RevokePlaytestKey, TokenMatches } from "./Token.js";
import { InstallBridge, InstallVersion, InstalledPluginVersion, IsNewer, ListReleases, LooksLikeVersion, NewestRelease } from "./PluginInstaller.js";
import { ArmClipboard, AskClipboard, DisarmClipboard, ReadClipboardImage, RegisterToasts, RestoreFlashing, ShowToast, WriteClipboard } from "./Notify.js";
import { ForgetConversation, GetModels } from "./Models.js";
import { Analyze, Warm } from "./Lint.js";
import { DescribeReturn, StopWatchingReturn, WatchReturn } from "./Keys.js";

type LoginState = {loggedIn: boolean, detail: string | null};

const LastLogin: {CheckedAt: number, Known: LoginState | null, Running: Promise<LoginState> | null} = {
  CheckedAt: 0,
  Known: null,
  Running: null,
};

function AskLogin() {
  if (LastLogin.Running) {
    return LastLogin.Running;
  }

  LastLogin.CheckedAt = Date.now();
  LastLogin.Running = new Promise<LoginState>((Resolve) => {
    exec("claude auth status", {timeout: 15000}, (Error, Stdout) => {
      if (Error) {
        Resolve({
          loggedIn: false,
          detail: Error.message,
        });
        return;
      }

      try {
        const Status = JSON.parse(Stdout) as {loggedIn?: unknown, authMethod?: string};
        Resolve({
          loggedIn: Boolean(Status.loggedIn),
          detail: Status.authMethod || null,
        });
      } catch {
        Resolve({
          loggedIn: /logged in/i.test(Stdout),
          detail: Stdout.trim(),
        });
      }
    });
  }).then((Found) => {
    LastLogin.Known = Found;
    LastLogin.CheckedAt = Date.now();
    LastLogin.Running = null;

    return Found;
  });

  return LastLogin.Running;
}

function CheckLogin() {
  const Stale = Date.now() - LastLogin.CheckedAt >= 30000;

  if (!LastLogin.Known) {
    return AskLogin();
  }

  if (Stale) {
    AskLogin().catch(() => {});
  }

  return Promise.resolve(LastLogin.Known);
}

type LintRun = { Done: boolean; Scripts: {path: string, lines: string[]}[] | null; Failed: string | null; At: number };

const LintRuns = new Map<string, LintRun>();
const LintSeen = new Map<string, {path: string, lines: string[]}[]>();

function StartLint(Wanted: {path: string, source: string}[], Raw: boolean, Tree: {path: string, className: string}[]): string {
  const Ticket = crypto.randomUUID();
  const Run: LintRun = {
    Done: false,
    Scripts: null,
    Failed: null,
    At: Date.now(),
  };
  const Fingerprint = crypto.createHash("sha1").update(JSON.stringify([Raw, Wanted, Tree])).digest("hex");
  const Remembered = LintSeen.get(Fingerprint);

  LintRuns.set(Ticket, Run);

  if (Remembered) {
    Run.Scripts = Remembered;
    Run.Done = true;

    return Ticket;
  }

  for (const [Key, Held] of LintRuns) {
    if (Held.Done && Date.now() - Held.At > 300000) {
      LintRuns.delete(Key);
    }
  }

  Analyze(Wanted, Raw, Tree).then((Checked) => {
    Run.Scripts = Checked;
    Run.Done = true;
    Run.At = Date.now();

    if (Checked === null) {
      return;
    }

    if (LintSeen.size >= 24) {
      LintSeen.delete(LintSeen.keys().next().value as string);
    }

    LintSeen.set(Fingerprint, Checked);
  }).catch((Trouble) => {
    Run.Failed = `The analyzer stopped: ${(Trouble as Error).message}`;
    Run.Done = true;
    Run.At = Date.now();
  });

  return Ticket;
}

function SendJson(Response: ServerResponse, StatusCode: number, Body: unknown) {
  Response.writeHead(StatusCode, {"Content-Type": "application/json"});
  Response.end(JSON.stringify(Body));
}

function SessionId(Value: unknown): string | null {
  return typeof Value === "string" && /^[\w-]{1,64}$/.test(Value) ? Value : null;
}

function Within<T>(Work: Promise<T>, Milliseconds: number, Otherwise: T): Promise<T> {
  let Timer: NodeJS.Timeout | undefined;

  return Promise.race([
    Work,
    new Promise<T>((Resolve) => {
      Timer = setTimeout(() => Resolve(Otherwise), Milliseconds);
    }),
  ]).finally(() => clearTimeout(Timer));
}

function PicturesFrom(Body: Record<string, any>): Picture[] {
  return Array.isArray(Body.images)
    ? Body.images.filter((Image) => Image && typeof Image.data === "string" && typeof Image.mediaType === "string").slice(0, 20)
    : [];
}

function TurnRequestFrom(Body: Record<string, any>, ConversationId: string | null): TurnRequest {
  return {
    Text: typeof Body.text === "string" ? Body.text : "",
    ConversationId,
    Images: [],
    Model: typeof Body.model === "string" ? Body.model : "default",
    Effort: typeof Body.effort === "string" ? Body.effort : null,
    AskForTools: Body.askForTools !== false,
    GuardTools: Body.guardTools === true,
    ExtraPrompt: Body.extraPrompt !== false,
    FastMode: Body.fastMode === true,
    Mode: typeof Body.mode === "string" ? Body.mode : DefaultMode,
    Bypass: Body.bypass === true && !PlaytestLive(),
    Escalate: Body.escalate === true,
    Place: Body.place && typeof Body.place === "object" ? Body.place : null,
    Folder: (ConversationId ? ListConversations().find((Entry) => Entry.id === ConversationId)?.folder : null) || (typeof Body.workingDirectory === "string" ? Body.workingDirectory : null),
    OutputStyle: typeof Body.outputStyle === "string" ? Body.outputStyle : "default",
    StepDown: Body.stepDown !== false,
  };
}

function ReadBody(Request: IncomingMessage, Limit = MaxBodyBytes): Promise<Record<string, any>> {
  return new Promise((Resolve, Reject) => {
    const Chunks: Buffer[] = [];
    let Size = 0;

    Request.on("data", (Chunk) => {
      Size += Chunk.length;

      if (Size <= Limit) {
        Chunks.push(Chunk);
      }
    });
    Request.on("end", () => {
      if (Size > Limit) {
        Reject(new Error(`That request was ${Math.ceil(Size / 1048576)} MB, over the ${Math.round(Limit / 1048576)} MB the bridge accepts.`));
        return;
      }

      const Raw = Buffer.concat(Chunks).toString("utf8");

      try {
        Resolve(Raw ? JSON.parse(Raw) : {});
      } catch {
        Reject(new Error("The plugin sent a request the bridge couldn't read."));
      }
    });
    Request.on("error", Reject);
  });
}

async function HandleConversations(Request: IncomingMessage, Response: ServerResponse, Segments: string[]) {
  const Id = Segments[1];

  if (Id && !/^[\w-]{1,64}$/.test(Id)) {
    SendJson(Response, 404, {error: "No such chat"});
    return;
  }

  if (Request.method === "GET" && !Id) {
    SendJson(Response, 200, {conversations: ListConversations()});
    return;
  }

  if (Request.method === "POST" && Id === "folder" && Segments[2] === "hidden") {
    const Body = await ReadBody(Request);
    const Folder = typeof Body.folder === "string" ? Body.folder.trim() : "";

    if (Folder === "") {
      SendJson(Response, 400, {error: "Pick a folder first."});
      return;
    }

    SetFolderHidden(Folder, Body.value === true);
    SendJson(Response, 200, {
      folder: Folder,
      hidden: Body.value === true,
    });
    return;
  }

  if (Request.method === "GET" && Id && Segments[2] === "image" && Segments[3]) {
    const Image = GetConversationImage(Id, Number(Segments[3]));

    if (!Image) {
      SendJson(Response, 404, {error: "No such image"});
      return;
    }

    SendJson(Response, 200, Image);
    return;
  }

  if (Request.method === "GET" && Id && Segments[2] === "exists") {
    SendJson(Response, 200, {exists: ConversationExists(Id)});
    return;
  }

  if (Request.method === "GET" && Id && Segments[2] === "subagents" && Segments[3]) {
    const Found = /^[\w-]{1,100}$/.test(Segments[3]) ? GetSubagent(Id, Segments[3], Segments[4] === "live") : null;

    if (!Found) {
      SendJson(Response, 404, {error: "That subagent has no transcript yet"});
      return;
    }

    SendJson(Response, 200, Found);
    return;
  }

  if (Request.method === "GET" && Id && Segments[2] === "chapters") {
    SendJson(Response, 200, {chapters: GetChapters(Id)});
    return;
  }

  if (Request.method === "GET" && Id) {
    const Query = new URL(Request.url as string, "http://127.0.0.1").searchParams;
    const Asked = Number(Query.get("count")) || 0;
    const Paging = (Query.get("before") || "") !== "";
    const Conversation = GetConversation(Id, Paging || Asked === 0 ? undefined : Asked);

    if (!Conversation) {
      SendJson(Response, 404, {error: "No such chat"});
      return;
    }

    const Total = Conversation.messages.length;
    const Before = Number(Query.get("before")) || Total;
    const First = Asked > 0 ? Math.max(0, Before - Asked) : 0;

    SendJson(Response, 200, {
      ...Conversation,
      messages: Conversation.messages.slice(First, Before),
      total: Total,
      first: First + 1,
    });
    return;
  }

  if (Request.method === "POST" && Id && Segments[2] === "title") {
    const Body = await ReadBody(Request);
    const Title = typeof Body.title === "string" ? Body.title.trim() : "";

    if (Title === "" || Title.length > 120) {
      SendJson(Response, 400, {error: "A chat name has to be between 1 and 120 characters."});
      return;
    }

    SendJson(Response, RenameConversation(Id, Title) ? 200 : 404, {
      id: Id,
      title: Title,
    });
    return;
  }

  if (Request.method === "POST" && Id && (Segments[2] === "starred" || Segments[2] === "archived")) {
    const Body = await ReadBody(Request);
    const Field = Segments[2] === "starred" ? "isStarred" : "isArchived";
    const Value = Body.value === true;

    if (!SetConversationFlag(Id, Field, Value)) {
      SendJson(Response, 404, {error: "No such chat"});
      return;
    }

    SendJson(Response, 200, {
      id: Id,
      [Segments[2]]: Value,
    });
    return;
  }

  if (Request.method === "POST" && Id && Segments[2] === "chapters") {
    const Body = await ReadBody(Request);
    const Chapters = Array.isArray(Body.chapters)
      ? Body.chapters
        .filter((Entry) => Entry && Number.isInteger(Entry.index) && typeof Entry.title === "string")
        .map((Entry) => ({
          index: Entry.index,
          title: Entry.title.slice(0, 80),
        }))
        .slice(0, 100)
      : [];

    SendJson(Response, 200, {chapters: SetChapters(Id, Chapters)});
    return;
  }

  if (Request.method === "POST" && Id && Segments[2] === "fork") {
    try {
      const Body = await ReadBody(Request);

      SendJson(Response, 200, {id: await ForkConversation(Id, SessionId(Body.upTo))});
    } catch (Error) {
      SendJson(Response, 500, {error: `Could not fork this chat: ${(Error as Error).message}`});
    }

    return;
  }

  if (Request.method === "DELETE" && Id) {
    CloseConversation(Id);
    ForgetConversation(Id);

    if (DeleteConversation(Id)) {
      SendJson(Response, 200, {deleted: Id});
    } else {
      SendJson(Response, 404, {error: "No such chat"});
    }
    return;
  }

  SendJson(Response, 404, {error: "Not found"});
}

let Armed = false;
let Picks: {name: string, description: string, at: number}[] = [];

let Picking: {Busy: boolean, Path: string | null} = {
  Busy: false,
  Path: null,
};

function BrowseForFolder() {
  if (Picking.Busy || process.platform !== "win32") {
    return Picking.Busy;
  }

  const Script = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "PickFolder.ps1");

  Picking = {
    Busy: true,
    Path: null,
  };
  execFile("powershell.exe", ["-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File", Script], {timeout: 600000}, (Error, Stdout) => {
    Picking = {
      Busy: false,
      Path: Error ? null : String(Stdout || "").trim(),
    };
  });

  return true;
}

function WarmUsage() {
  let Tries = 0;

  const Attempt = async () => {
    Tries += 1;

    if (await PollUsage() || Tries >= 10) {
      return;
    }

    setTimeout(Attempt, 2000);
  };

  setTimeout(Attempt, 1500);
}

export function StartServer(Port: number) {
  AskLogin().catch(() => {});
  RegisterToasts();
  AskClipboard("ready");
  RestoreFlashing();

  process.on("uncaughtException", (Error) => {
    console.error("Unexpected error, the bridge is staying up: " + (Error && Error.stack ? Error.stack : Error));
  });
  process.on("unhandledRejection", (Reason) => {
    const Thrown = Reason as Error;

    console.error("Unhandled rejection, the bridge is staying up: " + (Thrown && Thrown.stack ? Thrown.stack : Thrown));
  });

  const Server = http.createServer(async (Request, Response) => {
    const Url = new URL(Request.url as string, "http://127.0.0.1");
    const Segments = Url.pathname.split("/").filter(Boolean);

    try {
      if (Request.headers.origin !== undefined) {
        SendJson(Response, 403, {error: "Browser requests are not accepted"});
        return;
      }

      const Offered = Request.headers["x-claudio-token"];
      const FromPlaytest = !TokenMatches(Offered) && PlaytestKeyMatches(Offered);
      const Role = Url.searchParams.get("role") || "";

      if (!TokenMatches(Offered) && !(FromPlaytest && ((Url.pathname === "/studio/job" && (Request.method === "POST" || Role === "server" || Role === "client")) || Url.pathname === "/picker"))) {
        SendJson(Response, 401, {error: "This request did not come from the Claudio plugin"});
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/playtest/key") {
        SendJson(Response, 200, {key: IssuePlaytestKey()});
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/playtest/revoke") {
        RevokePlaytestKey((await ReadBody(Request)).key);
        SendJson(Response, 200, {revoked: true});
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/health") {
        const Login = await CheckLogin();

        SendJson(Response, 200, {
          name: "claudio",
          version: Version,
          protocolVersion: ProtocolVersion,
          loggedIn: Login && Login.loggedIn,
          loginDetail: Login && Login.detail,
          mcpServers: Object.keys(ReadMcpServers()),
          systemPrompt: SystemPromptFor(Object.keys(ReadMcpServers()), false),
          limits: GetLimits(),
          workingDirectory: LastUsedFolder() || null,
        });
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/notify") {
        const Body = await ReadBody(Request);

        const Shown = ShowToast(typeof Body.title === "string" ? Body.title : "Claudio", typeof Body.body === "string" ? Body.body.slice(0, 200) : "", {
          Flash: Body.flash !== false,
          Toast: Body.toast !== false,
          Banner: Body.banner !== false,
          Anywhere: Body.anywhere === true,
          Sound: Body.sound === true,
          Seconds: typeof Body.seconds === "number" && Body.seconds > 0 ? Math.min(Body.seconds, 600) : 0,
        });

        SendJson(Response, 200, {shown: Shown});
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/style") {
        const Body = await ReadBody(Request);

        ApplyStyleEverywhere(typeof Body.outputStyle === "string" ? Body.outputStyle : "default", Body.stepDown !== false);
        SendJson(Response, 200, {applied: true});
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/keys/watch") {
        const Body = await ReadBody(Request);

        if (Body.on === true) {
          WatchReturn();
        } else {
          StopWatchingReturn();
        }

        SendJson(Response, 200, DescribeReturn());
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/keys/return") {
        SendJson(Response, 200, DescribeReturn());
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/quit") {
        SendJson(Response, 200, {quitting: true});
        StopWatchingReturn(true);
        AbortAllTurns();
        setTimeout(() => process.exit(0), 500);
        return;
      }

      if (Segments[0] === "conversations") {
        await HandleConversations(Request, Response, Segments);
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/warm") {
        const Body = await ReadBody(Request);
        const ConversationId = SessionId(Body.conversationId);

        await Within(WarmConversation(TurnRequestFrom(Body, ConversationId)).catch(() => {}), 30000, undefined);

        SendJson(Response, 200, {context: GetBreakdown(ConversationId)});
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/chat") {
        const Body = await ReadBody(Request);

        if (typeof Body.text !== "string" || Body.text.trim() === "") {
          SendJson(Response, 400, {error: "The message is empty."});
          return;
        }

        const ConversationId = typeof Body.conversationId === "string" ? Body.conversationId : null;

        if ((ConversationId || typeof Body.requestId === "string") && (IsConversationBusy(ConversationId) || Body.now === true)) {
          const Joined = Body.now === true ? AddToTurn(typeof Body.requestId === "string" ? Body.requestId : null, ConversationId, Body.text, PicturesFrom(Body)) : null;

          if (!Joined) {
            SendJson(Response, 409, {error: "That chat is still answering. Stop it first."});
            return;
          }

          SendJson(Response, 200, DescribeTurn(Joined));
          return;
        }

        SendJson(Response, 200, DescribeTurn(StartTurn({
          ...TurnRequestFrom(Body, ConversationId),
          Images: PicturesFrom(Body),
        })));
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/studio/presence") {
        SendJson(Response, 200, {
          ...StudioPresence(),
          processes: await StudioProcesses(),
        });
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/studio/enqueue") {
        const Wanted = await ReadBody(Request);

        const Seconds = Number(Wanted.timeout);
        const Limit = Number.isFinite(Seconds) && Seconds > 0 ? Math.min(Seconds, 1800) * 1000 : (Wanted.kind === "execute" ? 300000 : undefined);

        SendJson(Response, 200, await RequestStudio(Wanted.kind, Wanted.input || {}, Limit, Wanted.role));
        return;
      }

      if (Url.pathname === "/studio/job") {
        if (Request.method === "GET") {
          const Able = Url.searchParams.get("canRun");
          const Attached = Url.searchParams.get("clients");
          const Plugin = Url.searchParams.get("plugin");

          SendJson(Response, 200, {job: TakeStudioJob(Url.searchParams.get("role") || "edit", Able === null ? undefined : Able === "true", Attached === null ? undefined : Number(Attached), Plugin || undefined)});
          return;
        }

        if (Request.method === "POST") {
          const Done = await ReadBody(Request);

          SendJson(Response, DeliverStudio(Done.id, Done.result, FromPlaytest) ? 200 : 409, {ok: true});
          return;
        }
      }

      if (Request.method === "POST" && Url.pathname === "/lint") {
        const Body = await ReadBody(Request);
        const Tree = (Array.isArray(Body.tree) ? Body.tree : []).filter((Entry: {path?: unknown, className?: unknown}) => Entry && typeof Entry.path === "string" && typeof Entry.className === "string").slice(0, 20000);
        const Sources = new Map<string, string>(Tree.filter((Entry: {source?: unknown}) => typeof Entry.source === "string").map((Entry: {path: string, source: string}) => [Entry.path, Entry.source]));
        const Wanted = (Array.isArray(Body.scripts) ? Body.scripts : [])
          .filter((Entry: {path?: unknown}) => Entry && typeof Entry.path === "string")
          .map((Entry: {path: string, source?: unknown}) => ({
            path: Entry.path,
            source: typeof Entry.source === "string" ? Entry.source : Sources.get(Entry.path) || "",
          }))
          .filter((Entry: {source: string}) => Entry.source !== "");

        if (Wanted.length > MostScriptsToCheck) {
          SendJson(Response, 413, {error: `${Wanted.length} scripts is more than the analyzer will check in one run. Narrow it with paths.`});
          return;
        }

        const Ticket = StartLint(Wanted, Body.raw === true, Tree);

        SendJson(Response, 200, {ticket: Ticket});
        return;
      }

      if (Request.method === "GET" && Segments[0] === "lint" && Segments[1]) {
        const Run = LintRuns.get(Segments[1]);

        if (!Run) {
          SendJson(Response, 404, {error: "That analyzer run has finished or expired."});
          return;
        }

        if (!Run.Done) {
          SendJson(Response, 200, {running: true});
          return;
        }

        LintRuns.delete(Segments[1]);

        if (Run.Failed || Run.Scripts === null) {
          SendJson(Response, 500, {error: Run.Failed || "The analyzer did not produce trustworthy output, so nothing was checked."});
          return;
        }

        SendJson(Response, 200, {scripts: Run.Scripts});
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/aun") {
        try {
          SendJson(Response, 200, await AvatarFor(AunId));
        } catch (Failure) {
          SendJson(Response, 502, {error: (Failure as Error).message});
        }

        return;
      }

      if (Request.method === "POST" && Url.pathname === "/decode") {
        const Body = await ReadBody(Request);
        const Decoded = typeof Body.data === "string" ? DecodeImage(Body.mediaType || "image/png", Body.data) : null;

        SendJson(Response, Decoded ? 200 : 400, Decoded || {error: "Could not decode that image"});
        return;
      }

      if (Request.method === "POST" && (Url.pathname === "/clipboard/arm" || Url.pathname === "/clipboard/disarm")) {
        const Body = await ReadBody(Request);
        const Marker = typeof Body.marker === "string" ? Body.marker.slice(0, 64) : "";
        const Outcome = Url.pathname === "/clipboard/arm" ? await ArmClipboard(Marker) : await DisarmClipboard(Marker);

        SendJson(Response, 200, {outcome: Outcome});
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/clipboard/text") {
        const Body = await ReadBody(Request);

        if (typeof Body.text !== "string" || Body.text === "") {
          SendJson(Response, 400, {error: "The message is empty."});
          return;
        }

        SendJson(Response, 200, {copied: await WriteClipboard(Body.text)});
        return;
      }

      if (Url.pathname === "/picker") {
        if (Request.method === "POST") {
          const Body = await ReadBody(Request);

          if (typeof Body.name === "string" && typeof Body.description === "string") {
            Picks.push({
              name: Body.name.slice(0, 120),
              description: Body.description.slice(0, 8000),
              at: Date.now(),
            });
            Picks = Picks.slice(-20);
          } else {
            Armed = Body.armed === true;
            Picks = [];
          }
        }

        Picks = Picks.filter((Entry) => Date.now() - Entry.at < 30000);

        const Waiting = Picks;

        if (Request.method === "GET" && Url.searchParams.get("take") === "1") {
          Picks = [];
        }

        SendJson(Response, 200, {
          armed: Armed,
          picks: Waiting,
        });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/clipboard") {
        const Image = await ReadClipboardImage(Url.searchParams.get("marker") || "");

        SendJson(Response, 200, Image || {
          data: null,
          id: null,
        });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/mcp") {
        SendJson(Response, 200, {servers: GetMcpServers()});
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/usage") {
        const For = SessionId(Url.searchParams.get("conversationId"));

        SendJson(Response, 200, {
          asked: (await Promise.all([
            Within(PollUsage(), 1000, false),
            Within(RefreshConversationContext(For), 3000, undefined),
          ]))[0],
          limits: GetLimits(),
          context: GetBreakdown(For),
        });
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/folder/browse") {
        SendJson(Response, 200, {started: BrowseForFolder()});
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/folder/browse") {
        SendJson(Response, 200, {
          pending: Picking.Busy,
          path: Picking.Path || "",
        });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/folder") {
        const Wanted = Url.searchParams.get("path") || "";
        let Usable = false;

        try {
          Usable = Wanted !== "" && fs.statSync(Wanted).isDirectory();
        } catch {
          Usable = false;
        }

        SendJson(Response, 200, {usable: Usable});
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/versions") {
        const Found = await ListReleases();
        const Newest = NewestRelease(Found);
        const Asked = Url.searchParams.get("plugin");
        const Plugin = LooksLikeVersion(Asked) ? Asked.trim().replace(/^v/, "") : InstalledPluginVersion();

        SendJson(Response, 200, {
          current: Plugin,
          bridge: Version,
          matched: Plugin !== null && Plugin === Version,
          known: Plugin !== null,
          latest: Newest ? Newest.version : null,
          newer: Boolean(Newest && Plugin && IsNewer(Newest.version, Plugin)),
          bridgeNewer: Boolean(Newest && IsNewer(Newest.version, Version)),
          releases: Found,
        });
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/versions") {
        const Body = await ReadBody(Request);

        if (!LooksLikeVersion(Body.version)) {
          SendJson(Response, 400, {error: "That isn't a version number. Use one like 1.0.0."});
          return;
        }

        const Version = Body.version.trim().replace(/^v/, "");

        try {
          const Commit = await InstallBridge(Version);
          const Installed = await InstallVersion(Version);

          const Restarter = spawn(process.execPath, [process.argv[1], "restart", "--port", String(Port)], {
            detached: true,
            stdio: "ignore",
            windowsHide: true,
          });

          Restarter.on("error", (Error) => console.error("Could not restart onto the new version: " + Error.message));
          Restarter.unref();
          SendJson(Response, 200, {
            installed: Installed,
            commit: Commit,
            restarting: true,
          });
        } catch (Error) {
          SendJson(Response, 502, {error: (Error as Error).message});
        }

        return;
      }

      if (Request.method === "GET" && Url.pathname === "/models") {
        SendJson(Response, 200, {models: GetModels()});
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/commands") {
        const Open = Url.searchParams.get("conversation");
        const Folder = (Open ? ListConversations().find((Entry) => Entry.id === Open)?.folder : null) || Url.searchParams.get("folder");

        SendJson(Response, 200, GetCommands(Folder));
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/chat/active") {
        const Wanted = Url.searchParams.get("conversation") || "";
        const Turn = ActiveTurnFor(Wanted);

        SendJson(Response, 200, {
          turn: Turn ? DescribeTurn(Turn) : null,
          endedAt: LastEndedAt(Wanted),
        });
        return;
      }

      if (Segments[0] === "turn" && Segments[1]) {
        const Turn = GetTurn(Segments[1]);

        if (!Turn) {
          SendJson(Response, 404, {error: "That reply is no longer running."});
          return;
        }

        if (Request.method === "POST" && Segments[2] === "answer") {
          const Given = await ReadBody(Request);
          const Answers = Given.answers && typeof Given.answers === "object" ? Given.answers : null;

          SendJson(Response, AnswerQuestion(Turn, Given.id, Answers) ? 200 : 409, DescribeTurn(Turn));
          return;
        }

        if (Request.method === "POST" && Segments[2] === "permission") {
          const Body = await ReadBody(Request);

          SendJson(Response, AnswerPermission(Turn, Body.id, Boolean(Body.allow), Boolean(Body.always)) ? 200 : 409, DescribeTurn(Turn));
          return;
        }

        if (Request.method === "GET" && Segments[2] === "image" && Segments[3]) {
          const Wanted = Number(Segments[3]);
          const Image = Turn.Images[Wanted - 1];

          if (!Image) {
            SendJson(Response, 404, {error: "No such image"});
            return;
          }

          SendJson(Response, 200, Image);
          ReleaseImage(Turn, Wanted);
          return;
        }

        if (Request.method === "POST" && Segments[2] === "cancel") {
          CancelTurn(Turn);
          SendJson(Response, 200, DescribeTurn(Turn));
          return;
        }

        if (Request.method === "GET" && !Segments[2]) {
          await WaitForChange(Turn, Number(Url.searchParams.get("version") || -1), LongPollMilliseconds);
          SendJson(Response, 200, DescribeTurn(Turn));
          return;
        }
      }

      SendJson(Response, 404, {error: "Not found"});
    } catch (Error) {
      SendJson(Response, 500, {error: (Error as Error).message});
    }
  });

  Server.on("error", (Error) => {
    console.error((Error as NodeJS.ErrnoException).code === "EADDRINUSE"
      ? `Port ${Port} is already in use. Is another Claudio bridge running? Use --port to pick another.`
      : `Could not listen on port ${Port}: ${Error.message}`);
    process.exit(1);
  });

  Server.listen(Port, "127.0.0.1", () => {
    const Reached = HandToken();

    const Root = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))));
    const Tools = StudioTools({
      Reach: (async () => ({})) as Reacher,
      ReachIn: (async () => ({})) as ReacherIn,
      Presence: async () => "",
      RuntimeLive: async () => false,
    }).length + 1;

    Serving(Version, Root, Tools);

    console.log(`Claudio bridge listening on http://127.0.0.1:${Port}`);
    console.log(`Claudio ${Version} from ${Root}, serving ${Tools} tools`);

    if (Tools < 2) {
      console.error("No tools were built, so Claude can't reach Studio. This is a Claudio bug, please report it.");
    }
    Warm().catch(() => {});

    if (Reached === 0) {
      console.error("Could not hand the plugin its key: Studio has no settings file yet. Open Studio once, then restart the bridge.");
    }
    DiscoverCommands(LastUsedFolder());
    KeepSpareWarm();
    WarmUsage();
  });

  return Server;
}