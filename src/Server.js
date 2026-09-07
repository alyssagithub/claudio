import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { exec, execFile } from "node:child_process";
import { AunId, DefaultMode, LongPollMilliseconds, MaxBodyBytes, ProtocolVersion, Version, WorkingDirectory } from "./Config.js";
import { SystemPromptFor } from "./Config.js";
import { GetLimits, GetBreakdown, PollUsage } from "./ClaudeSession.js";
import { LastUsedFolder, UsableFolder, AbortAllTurns, AnswerPermission, AnswerQuestion, AnswerStudio, CancelTurn, DescribeTurn, DiscoverCommands, ForkConversation, GetCommands, GetMcpServers, GetTurn, IsConversationBusy, KeepSpareWarm, ReadMcpServers, ReleaseImage, StartTurn, WaitForChange } from "./ClaudeSession.js";
import { ConversationExists, DeleteConversation, GetChapters, GetConversation, GetConversationImage, ListConversations, RenameConversation, SetChapters, SetConversationFlag } from "./Conversations.js";
import { DecodeImage } from "./Images.js";
import { AvatarFor } from "./EasterEgg.js";
import { HandToken, TokenMatches } from "./Token.js";
import { InstallBridge, InstallVersion, InstalledPluginVersion, IsNewer, ListReleases, LooksLikeVersion, NewestRelease } from "./PluginInstaller.js";
import { ArmClipboard, DisarmClipboard, ReadClipboardImage, ShowToast, WriteClipboard } from "./Notify.js";
import { ForgetConversation, GetModels } from "./Models.js";
import { Analyze, Warm } from "./Lint.js";
import { RestartBridge } from "./Startup.js";

let LastLogin = { CheckedAt: 0, Result: null };

function CheckLogin() {
  if (Date.now() - LastLogin.CheckedAt < 30000) {
    return LastLogin.Result;
  }

  LastLogin = {
    CheckedAt: Date.now(),
    Result: new Promise((Resolve) => {
      exec("claude auth status", { timeout: 15000 }, (Error, Stdout) => {
        if (Error) {
          Resolve({ loggedIn: false, detail: Error.message });
          return;
        }

        try {
          const Status = JSON.parse(Stdout);
          Resolve({ loggedIn: Boolean(Status.loggedIn), detail: Status.authMethod || null });
        } catch {
          Resolve({ loggedIn: /logged in/i.test(Stdout), detail: Stdout.trim() });
        }
      });
    }),
  };

  return LastLogin.Result;
}

function SendJson(Response, StatusCode, Body) {
  Response.writeHead(StatusCode, { "Content-Type": "application/json" });
  Response.end(JSON.stringify(Body));
}

function ReadBody(Request) {
  return new Promise((Resolve, Reject) => {
    const Chunks = [];
    let Size = 0;

    Request.on("data", (Chunk) => {
      Size += Chunk.length;

      if (Size > MaxBodyBytes) {
        Reject(new Error("Body is too large"));
        Request.destroy();

        return;
      }

      Chunks.push(Chunk);
    });
    Request.on("end", () => {
      const Raw = Buffer.concat(Chunks).toString("utf8");

      try {
        Resolve(Raw ? JSON.parse(Raw) : {});
      } catch {
        Reject(new Error("Body is not valid JSON"));
      }
    });
    Request.on("error", Reject);
  });
}

async function HandleConversations(Request, Response, Segments) {
  const Id = Segments[1];

  if (Request.method === "GET" && !Id) {
    SendJson(Response, 200, { conversations: ListConversations() });
    return;
  }

  if (Request.method === "GET" && Id && Segments[2] === "image" && Segments[3]) {
    const Image = GetConversationImage(Id, Number(Segments[3]));

    if (!Image) {
      SendJson(Response, 404, { error: "No such image" });
      return;
    }

    SendJson(Response, 200, Image);
    return;
  }

  if (Request.method === "GET" && Id && Segments[2] === "exists") {
    SendJson(Response, 200, { exists: ConversationExists(Id) });
    return;
  }

  if (Request.method === "GET" && Id && Segments[2] === "chapters") {
    SendJson(Response, 200, { chapters: GetChapters(Id) });
    return;
  }

  if (Request.method === "GET" && Id) {
    const Conversation = GetConversation(Id);

    if (!Conversation) {
      SendJson(Response, 404, { error: "No such conversation" });
      return;
    }

    SendJson(Response, 200, Conversation);
    return;
  }

  if (Request.method === "POST" && Id && Segments[2] === "title") {
    const Body = await ReadBody(Request);
    const Title = typeof Body.title === "string" ? Body.title.trim() : "";

    if (Title === "" || Title.length > 120) {
      SendJson(Response, 400, { error: "A chat name has to be between 1 and 120 characters." });
      return;
    }

    SendJson(Response, RenameConversation(Id, Title) ? 200 : 404, { id: Id, title: Title });
    return;
  }

  if (Request.method === "POST" && Id && (Segments[2] === "starred" || Segments[2] === "archived")) {
    const Body = await ReadBody(Request);
    const Field = Segments[2] === "starred" ? "isStarred" : "isArchived";
    const Value = Body.value === true;

    if (!SetConversationFlag(Id, Field, Value)) {
      SendJson(Response, 404, { error: "No such conversation" });
      return;
    }

    SendJson(Response, 200, { id: Id, [Segments[2]]: Value });
    return;
  }

  if (Request.method === "POST" && Id && Segments[2] === "chapters") {
    const Body = await ReadBody(Request);
    const Chapters = Array.isArray(Body.chapters)
      ? Body.chapters
        .filter((Entry) => Number.isInteger(Entry.index) && typeof Entry.title === "string")
        .map((Entry) => ({ index: Entry.index, title: Entry.title.slice(0, 80) }))
        .slice(0, 100)
      : [];

    SendJson(Response, 200, { chapters: SetChapters(Id, Chapters) });
    return;
  }

  if (Request.method === "POST" && Id && Segments[2] === "fork") {
    try {
      SendJson(Response, 200, { id: await ForkConversation(Id) });
    } catch (Error) {
      SendJson(Response, 500, { error: `Could not fork this chat: ${Error.message}` });
    }

    return;
  }

  if (Request.method === "DELETE" && Id) {
    ForgetConversation(Id);

    if (DeleteConversation(Id)) {
      SendJson(Response, 200, { deleted: Id });
    } else {
      SendJson(Response, 403, { error: "Delete this chat from the Claude desktop app instead." });
    }
    return;
  }

  SendJson(Response, 404, { error: "Not found" });
}

let Armed = false;
let Picks = [];

let Picking = { Busy: false, Path: null };

function BrowseForFolder() {
  if (Picking.Busy || process.platform !== "win32") {
    return Picking.Busy;
  }

  const Script = path.join(path.dirname(fileURLToPath(import.meta.url)), "PickFolder.ps1");

  Picking = { Busy: true, Path: null };
  execFile("powershell.exe", ["-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File", Script], { timeout: 600000 }, (Error, Stdout) => {
    Picking = { Busy: false, Path: Error ? null : String(Stdout || "").trim() };
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

export function StartServer(Port) {
  process.on("uncaughtException", (Error) => {
    console.error("Unexpected error, the bridge is staying up: " + (Error && Error.stack ? Error.stack : Error));
  });
  process.on("unhandledRejection", (Reason) => {
    console.error("Unhandled rejection, the bridge is staying up: " + (Reason && Reason.stack ? Reason.stack : Reason));
  });

  const Server = http.createServer(async (Request, Response) => {
    const Url = new URL(Request.url, "http://127.0.0.1");
    const Segments = Url.pathname.split("/").filter(Boolean);

    try {
      if (Request.headers.origin !== undefined) {
        SendJson(Response, 403, { error: "Browser requests are not accepted" });
        return;
      }

      if (!TokenMatches(Request.headers["x-claudio-token"])) {
        SendJson(Response, 401, { error: "This request did not come from the Claudio plugin" });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/health") {
        const Login = await CheckLogin();

        SendJson(Response, 200, {
          name: "claudio",
          version: Version,
          protocolVersion: ProtocolVersion,
          loggedIn: Login.loggedIn,
          loginDetail: Login.detail,
          mcpServers: Object.keys(ReadMcpServers()),
          systemPrompt: SystemPromptFor(Object.keys(ReadMcpServers())),
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
        });

        SendJson(Response, 200, { shown: Shown });
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/quit") {
        SendJson(Response, 200, { quitting: true });
        AbortAllTurns();
        setTimeout(() => process.exit(0), 500);
        return;
      }

      if (Segments[0] === "conversations") {
        await HandleConversations(Request, Response, Segments);
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/chat") {
        const Body = await ReadBody(Request);

        if (typeof Body.text !== "string" || Body.text.trim() === "") {
          SendJson(Response, 400, { error: "text is required" });
          return;
        }

        const ConversationId = typeof Body.conversationId === "string" ? Body.conversationId : null;

        if (ConversationId && IsConversationBusy(ConversationId)) {
          SendJson(Response, 409, { error: "That chat is still answering. Stop it first." });
          return;
        }

        if (!UsableFolder(Body.workingDirectory) && !ConversationId) {
          SendJson(Response, 400, { error: "Pick a folder for Claude to work in first. Settings, then Working folder." });
          return;
        }

        const Images = Array.isArray(Body.images)
          ? Body.images.filter((Image) => typeof Image.data === "string" && typeof Image.mediaType === "string").slice(0, 4)
          : [];

        SendJson(Response, 200, DescribeTurn(StartTurn({
          Text: Body.text,
          ConversationId,
          Images,
          Model: typeof Body.model === "string" ? Body.model : "auto",
          Effort: typeof Body.effort === "string" ? Body.effort : null,
          AskForTools: Body.askForTools !== false,
          GuardTools: Body.guardTools === true,
          ExtraPrompt: Body.extraPrompt !== false,
          FastMode: Body.fastMode === true,
          Mode: typeof Body.mode === "string" ? Body.mode : DefaultMode,
          Bypass: Body.bypass === true,
          Escalate: Body.escalate === true,
          Place: Body.place && typeof Body.place === "object" ? Body.place : null,
          Folder: typeof Body.workingDirectory === "string" ? Body.workingDirectory : null,
        })));
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/lint") {
        const Body = await ReadBody(Request);
        const Usable = (Entry) => Entry && typeof Entry.path === "string" && typeof Entry.source === "string" && Entry.source !== "";
        const Wanted = (Array.isArray(Body.scripts) ? Body.scripts : []).filter(Usable).slice(0, 20);
        const Tree = (Array.isArray(Body.tree) ? Body.tree : []).filter(Usable).slice(0, 3000);

        SendJson(Response, 200, { scripts: (await Analyze(Wanted, Body.raw === true, Tree)) || [] });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/aun") {
        try {
          SendJson(Response, 200, await AvatarFor(AunId));
        } catch (Failure) {
          SendJson(Response, 502, { error: Failure.message });
        }

        return;
      }

      if (Request.method === "POST" && Url.pathname === "/decode") {
        const Body = await ReadBody(Request);
        const Decoded = typeof Body.data === "string" ? DecodeImage(Body.mediaType || "image/png", Body.data) : null;

        SendJson(Response, Decoded ? 200 : 400, Decoded || { error: "Could not decode that image" });
        return;
      }

      if (Request.method === "POST" && (Url.pathname === "/clipboard/arm" || Url.pathname === "/clipboard/disarm")) {
        const Body = await ReadBody(Request);
        const Marker = typeof Body.marker === "string" ? Body.marker.slice(0, 64) : "";
        const Outcome = Url.pathname === "/clipboard/arm" ? await ArmClipboard(Marker) : await DisarmClipboard(Marker);

        SendJson(Response, 200, { outcome: Outcome });
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/clipboard/text") {
        const Body = await ReadBody(Request);

        if (typeof Body.text !== "string" || Body.text === "") {
          SendJson(Response, 400, { error: "text is required" });
          return;
        }

        SendJson(Response, 200, { copied: await WriteClipboard(Body.text) });
        return;
      }

      if (Url.pathname === "/picker") {
        if (Request.method === "POST") {
          const Body = await ReadBody(Request);

          if (typeof Body.name === "string" && typeof Body.description === "string") {
            Picks.push({ name: Body.name.slice(0, 120), description: Body.description.slice(0, 8000), at: Date.now() });
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

        SendJson(Response, 200, { armed: Armed, picks: Waiting });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/clipboard") {
        const Image = await ReadClipboardImage();

        SendJson(Response, 200, Image || { data: null, id: null });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/mcp") {
        SendJson(Response, 200, { servers: GetMcpServers() });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/usage") {
        const For = Url.searchParams.get("conversationId");
        const Asked = await PollUsage(For);

        SendJson(Response, 200, { asked: Asked, limits: GetLimits(), context: GetBreakdown(For) });
        return;
      }

      if (Request.method === "POST" && Url.pathname === "/folder/browse") {
        SendJson(Response, 200, { started: BrowseForFolder() });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/folder/browse") {
        SendJson(Response, 200, { pending: Picking.Busy, path: Picking.Path || "" });
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

        SendJson(Response, 200, { usable: Usable });
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

        if (typeof Body.version !== "string" || !/^[0-9.]+$/.test(Body.version)) {
          SendJson(Response, 400, { error: "A version looks like 1.0.0" });
          return;
        }

        try {
          const Commit = await InstallBridge(Body.version);
          const Installed = await InstallVersion(Body.version);

          SendJson(Response, 200, { installed: Installed, commit: Commit, restarting: true });
          setTimeout(() => {
            RestartBridge(Port).catch((Error) => console.error("Could not restart onto the new version: " + Error.message));
          }, 500);
        } catch (Error) {
          SendJson(Response, 502, { error: Error.message });
        }

        return;
      }

      if (Request.method === "GET" && Url.pathname === "/models") {
        SendJson(Response, 200, { models: GetModels() });
        return;
      }

      if (Request.method === "GET" && Url.pathname === "/commands") {
        SendJson(Response, 200, GetCommands());
        return;
      }

      if (Segments[0] === "turn" && Segments[1]) {
        const Turn = GetTurn(Segments[1]);

        if (!Turn) {
          SendJson(Response, 404, { error: "No such turn" });
          return;
        }

        if (Request.method === "POST" && Segments[2] === "studio") {
          const Done = await ReadBody(Request);

          SendJson(Response, AnswerStudio(Turn, Done.id, Done.result) ? 200 : 409, DescribeTurn(Turn));
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
            SendJson(Response, 404, { error: "No such image" });
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

      SendJson(Response, 404, { error: "Not found" });
    } catch (Error) {
      SendJson(Response, 500, { error: Error.message });
    }
  });

  Server.on("error", (Error) => {
    if (Error.code === "EADDRINUSE") {
      console.error(`Port ${Port} is already in use. Is another Claudio bridge running? Use --port to pick another.`);
      process.exit(1);
    }

    throw Error;
  });

  Server.listen(Port, "127.0.0.1", () => {
    const Reached = HandToken();

    console.log(`Claudio bridge listening on http://127.0.0.1:${Port}`);
    Warm().catch(() => {});

    if (Reached === 0) {
      console.error("Could not hand the plugin its key: Studio has no settings file yet. Open Studio once, then restart the bridge.");
    }
    DiscoverCommands();
    KeepSpareWarm();
    WarmUsage();
  });

  return Server;
}
