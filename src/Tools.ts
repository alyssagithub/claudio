import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { ReadDiskTree } from "./DiskTree.js";
import type { DiskNode } from "./DiskTree.js";
import { execFile } from "node:child_process";
import { z } from "zod/v3";
import { ReadReport, PropertyReport, ApiReport, ExecuteReport, FindReport, SourceReport, SelectReport, LogReport, LintReport } from "./Ask.js";
import type { LogAnswer, ExecuteAnswer } from "./Ask.js";
import { QuietFlash } from "./Notify.js";
import { CallOpenCloud } from "./OpenCloud.js";
import { PadInputs, PressPad } from "./Gamepad.js";

const ExecuteDescription = [
  "Run Luau inside the open place and get back what it returned, what it printed, and where it failed.",
  "target picks where: edit is the editor and the default, server and client are the running play session and need one open.",
  "Changes are recorded as one undo step; pass readOnly when you only want to look.",
  "Set timeout in seconds when the code is expected to take a while, up to thirty minutes; it defaults to five minutes.",
  "In edit, plugin is Claudio's own Plugin object, so plugin APIs and plugin-development harnesses work. Call _G.ClaudioFresh(module) to require past the cache; it also reloads every other module whose source changed since Studio opened, so edited dependencies are not stale.",
  "Code runs on Studio's main thread and cannot be interrupted, so a loop that never yields freezes all of Studio, stalls every other call, and makes Studio offer to kill the plugin. Call breathe() inside any loop over many instances, scripts or lines; it yields only when the frame's time is used up, so calling it every iteration costs almost nothing.",
  "Never run patterns that start or end with a greedy class, such as [^\\n]*word[^\\n]*, over a whole script's source: their cost grows with the square of the line length. Split the source into lines with gmatch(\"[^\\n]+\") and test each with find(word, 1, true).",
].join(" ");

const InputDescription = [
  "Send input to the running playtest: press, type, key, hover, scroll or drag.",
  "Interface actions name an instance path instead of guessing screen coordinates.",
  "press clicks the middle of a GuiObject, type sends text to whatever has keyboard focus, key presses and releases a KeyCode by name.",
  "hover moves the pointer onto a GuiObject, scroll turns the wheel over one, and drag holds the button from a GuiObject to another path or by an x and y offset.",
  "A right-button drag, or a drag with no path, holds the button with the cursor locked and sends real mouse movement, so InputChanged deltas and GetMouseDelta see it; use it to turn a camera.",
  "Positions in answers are in the same space as AbsolutePosition, below the top bar. x and y are a relative move, so prefer to with a target path when dropping onto something. hold waits at the end before releasing, for drops that wait for the pointer to settle.",
  "Needs a play session with a character.",
  "Input that reaches nothing still reports as sent, so check the place afterwards.",
  "Roblox refuses simulated input on CoreGui, such as purchase and prompt windows. Take a window capture and use click with window set to true and the capture's pixel coordinates; that sends a real click to the Studio window. Studio test purchases cost nothing.",
].join(" ");

const PlaytestDescription = [
  "Start, stop or inspect a playtest of the open place.",
  "Always stop what you started.",
  "Check status first rather than assuming.",
  "start and players wait until the server and every client have loaded and can run code, up to three minutes, so the session is usable as soon as the call returns.",
  "This runs without a player character, so LocalPlayer and PlayerGui are not available.",
  "A multiplayer test opens a server and one client per player, each its own Studio process of a gigabyte or more, measured from the ones already running. Before starting one or adding players the tool checks they fit in free memory with room to spare, counting the page file, and refuses when they would not, because running out crashes the whole machine. Pass force only when the user asks for it.",
  "stop closes the test's own Studio windows from outside when the session does not answer, so a hung multiplayer test can always be stopped; the editor is never touched.",
].join(" ");

function StudioMemory(): Promise<{Editor: number, Test: number, Room: number}> {
  const [Program, Arguments, Scale] = process.platform === "win32"
    ? ["powershell", ["-NoProfile", "-Command", "\"$((Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Sort-Object PrivateMemorySize64 -Descending | ForEach-Object { $_.PrivateMemorySize64 }) -join ',') $((Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory * 1024)\""], 1]
    : ["sh", ["-c", "echo $(ps -axo rss,comm | grep -i RobloxStudio | sort -rn | awk '{print $1}' | paste -sd, -) 0"], 1024];

  return new Promise((Resolve) => {
    execFile(Program as string, Arguments as string[], {
      encoding: "utf8",
      timeout: 8000,
      windowsHide: true,
    }, (Trouble, Said) => {
      const [Sizes, Room] = String(Said || "").trim().split(/\s+/);
      const Each = String(Sizes || "").split(",").map(Number).filter((Size) => Size > 0).map((Size) => Size * (Scale as number));

      Resolve({
        Editor: Trouble ? 0 : Each[0] || 0,
        Test: Trouble ? 0 : Math.max(0, ...Each.slice(1)),
        Room: Trouble || !Number(Room) ? os.freemem() : Number(Room),
      });
    });
  });
}

async function Headroom(Clients: number, Starting: boolean): Promise<string | null> {
  const Gigabyte = 1024 * 1024 * 1024;
  const Processes = Clients + (Starting ? 1 : 0);
  const Gigabytes = (Bytes: number) => (Bytes / Gigabyte).toFixed(1);
  const Began = Date.now();
  let Measured = await StudioMemory();
  let Each = Math.max(1.2 * Gigabyte, Measured.Test || Measured.Editor * 0.25);
  let Needed = Processes * Each + 0.5 * Gigabyte;
  let Most = Measured.Room;

  while (Measured.Room < Needed && Date.now() - Began < 20000) {
    await new Promise((Resolve) => setTimeout(Resolve, 2000));
    Measured = await StudioMemory();
    Each = Math.max(1.2 * Gigabyte, Measured.Test || Measured.Editor * 0.25);
    Needed = Processes * Each + 0.5 * Gigabyte;
    Most = Math.max(Most, Measured.Room);
  }

  if (Measured.Room >= Needed) {
    return null;
  }

  return `Not starting that: ${Starting ? "a server and " : ""}${Clients} client${Clients === 1 ? "" : "s"} are ${Processes} Studio processes of about ${Gigabytes(Each)} GB each, plus room to spare, so about ${Gigabytes(Needed)} GB, and over 20 seconds of watching this machine had at most ${Gigabytes(Most)} GB free even counting the page file. Running out crashes the whole machine, not just Studio. Use fewer players, or pass force only if the user asks for it.`;
}

let QualityChanged = false;

const LintDescription = [
  "Check scripts in the open place for analyzer warnings, including scripts nobody has edited.",
  "Pass paths to narrow it, or leave it empty to check everything.",
  "Report what it finds rather than fixing unasked, because pre-existing warnings were already there.",
].join(" ");

export type Reacher = <Found>(Kind: string, Input?: unknown, Timeout?: number) => Promise<Found>;

export type ReacherIn = <Found>(Role: string, Kind: string, Input?: unknown, Timeout?: number) => Promise<Found>;

export type Dependencies = {
  Reach: Reacher;
  ReachIn: ReacherIn;
  Presence: () => Promise<string>;
  LiveSession: () => Promise<{Players: number | null, Ready: number, Able: boolean} | null>;
};

export type ToolContent = { type: "text"; text: string } | { type: "image"; data: string; mimeType: string };

export type ToolAnswer = { content: ToolContent[] };

export type StudioTool = {
  Name: string;
  Description: string;
  Schema: z.ZodRawShape;
  Run(Input: Record<string, unknown>, Extra?: unknown): Promise<ToolAnswer>;
};

type SaidAnswer = { error?: string; text?: string } | null | undefined;

function Said(Found: SaidAnswer, Missing: string): string {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  return Found.text || Missing;
}

export function StudioTools(Deps: Dependencies): StudioTool[] {
  const { Reach, ReachIn, Presence, LiveSession } = Deps;

  async function NeedsSession(What: string): Promise<string | null> {
    return (await LiveSession()) ? null : What;
  }

  // Stop returns as soon as the session takes the request, but Studio needs a while to tear the playtest
  // down; wait until the editor reports it is back in edit mode so the next start is not refused.
  async function WaitUntilStopped(Signal?: AbortSignal): Promise<string> {
    const Said = await WaitForEditMode(Signal);

    if (!QualityChanged || !Said.includes("back in edit mode")) {
      return Said;
    }

    QualityChanged = false;
    await Reach("quality", {});

    return `${Said} Studio's graphics level was put back to automatic.`;
  }

  async function WaitForEditMode(Signal?: AbortSignal): Promise<string> {
    const Began = Date.now();

    while (Date.now() - Began < 60000) {
      if (Signal && Signal.aborted) {
        return " Stopped waiting for it to close because the call was cancelled.";
      }

      const Status: { text?: string } | null = await Reach("playtest", {action: "status"});

      if (Status && typeof Status.text === "string" && Status.text.startsWith("No playtest") && !(await LiveSession())) {
        return ` Studio was back in edit mode ${Math.round((Date.now() - Began) / 1000)}s later.`;
      }

      await new Promise((Resolve) => setTimeout(Resolve, 500));
    }

    return await ForceStop(" Studio had still not left the playtest after a minute.");
  }

  async function ForceStop(Before: string): Promise<string> {
    const { CloseTestProcesses } = await import("./StudioPresence.js");
    const Closed = await CloseTestProcesses();

    if (Closed === 0) {
      return `${Before} No separate test windows were open to close from outside, so stop it from Studio's toolbar.`;
    }

    return `${Before} Closed ${Closed} test Studio window${Closed === 1 ? "" : "s"} from outside, leaving the editor alone.`;
  }

  async function WaitUntilLoaded(Clients: number, Signal?: AbortSignal): Promise<string> {
    const Began = Date.now();

    while (Date.now() - Began < 180000) {
      if (Signal && Signal.aborted) {
        return " Stopped waiting for it to load because the call was cancelled.";
      }

      const Session = await LiveSession();

      if (Session && Session.Able && Session.Ready >= Clients && (Clients === 0 || (Session.Players || 0) >= Clients)) {
        return ` Everything loaded ${Math.round((Date.now() - Began) / 1000)}s later: the server${Clients === 0 ? "" : Clients === 1 ? " and the client" : ` and all ${Clients} clients`} can run code now, and the server's player list has ${Session.Players || 0} player${Session.Players === 1 ? "" : "s"} in it.`;
      }

      await new Promise((Resolve) => setTimeout(Resolve, 1000));
    }

    const Session = await LiveSession();

    if (!Session) {
      return " The session never became reachable within three minutes, so nothing can run in it yet. It needs Allow HTTP Requests turned on in Game Settings.";
    }

    if (!Session.Able) {
      return " After three minutes the server is up but Claudio's plugin is not running inside it, so code cannot run there yet.";
    }

    return ` After three minutes only ${Session.Ready} of ${Clients} clients had finished loading and the server's player list has ${Session.Players || 0}. Check the place before relying on the rest.`;
  }

  async function ReadHiddenProperties(Path: string, Names: string[] | undefined, Fresh: boolean): Promise<string> {
    const File = path.join(process.env.LOCALAPPDATA || "", "Roblox", "server.rbxl");
    const Age = fs.existsSync(File) ? Date.now() - fs.statSync(File).mtimeMs : Infinity;

    if (Fresh || Age > 30 * 60 * 1000) {
      if (await LiveSession()) {
        return "A playtest is running, so Claudio cannot make a fresh copy of the place to read from. Stop it first, or leave fresh off to use the last copy if there is one.";
      }

      const Began = Date.now();

      await Reach("execute", {readOnly: true, code: "task.spawn(function() pcall(function() game:GetService(\"StudioTestService\"):ExecuteMultiplayerTestAsync(0, {}) end) end) return true"});

      while (Date.now() - Began < 120000 && !(fs.existsSync(File) && fs.statSync(File).mtimeMs > Began)) {
        await new Promise((Resolve) => setTimeout(Resolve, 1000));
      }

      await new Promise((Resolve) => setTimeout(Resolve, 1500));
      await (await import("./StudioPresence.js")).CloseTestProcesses();

      if (!(fs.existsSync(File) && fs.statSync(File).mtimeMs > Began)) {
        return "Studio did not write a copy of the place within two minutes, so the hidden properties could not be read.";
      }
    }

    const { ReadHidden } = await import("./PlaceFile.js");
    const Read = ReadHidden(File, Path);

    if ("error" in Read) {
      return Read.error;
    }

    const Wanted = Object.entries(Read.properties).filter(([Name]) => !Names || Names.some((Given) => Given.toLowerCase() === Name.toLowerCase()));
    const Enums = Wanted.filter(([, Value]) => Value.kind === "enum").map(([Name, Value]) => [Name, Value.value]);
    let Named: Record<string, string> = {};

    if (Enums.length > 0) {
      const Answer = await Reach("execute", {readOnly: true, code: `local Out = {}
for _, Pair in game:GetService("HttpService"):JSONDecode(${JSON.stringify(JSON.stringify(Enums))}) do
	for _, Kind in {Pair[1], (Pair[1]:gsub("%d+$", ""))} do
		local Ok, Item = pcall(function() return (Enum :: any)[Kind]:FromValue(Pair[2]) end)
		if Ok and Item then Out[Pair[1]] = tostring(Item) break end
	end
end
return game:GetService("HttpService"):JSONEncode(Out)`}) as { result?: unknown } | null;

      try {
        Named = JSON.parse(String(Answer && Answer.result));
      } catch {
        Named = {};
      }
    }

    const Lines = Wanted.map(([Name, Value]) => `${Name} = ${Named[Name] || (Value.kind === "enum" ? `enum value ${Value.value}` : JSON.stringify(Value.value))}`);
    const When = Math.round((Date.now() - fs.statSync(File).mtimeMs) / 60000);

    return [`${Path}, read from a copy of the place made ${When <= 0 ? "just now" : `${When} minute${When === 1 ? "" : "s"} ago`}:`, ...Lines, ...(Lines.length === 0 ? ["No properties by those names."] : [])].join("\n");
  }

  return [
    {
      Name: "instances",
      Description: "Say whether Studio is open and whether the Claudio plugin has checked in. Ask this before assuming nothing is connected, and never open Studio yourself on the strength of an empty answer.",
      Schema: {},
      Run: async () => ({content: [{
        type: "text",
        text: await Presence(),
      }]}),
    },
    {
      Name: "read",
      Description: "Read a part of the open place in one call: the instance tree under a path, plus the source of scripts in it. Prefer this over walking the tree with separate calls.",
      Schema: {
        path: z.string().optional().describe("Where to start, such as ServerScriptService. Defaults to the whole place."),
        depth: z.number().optional().describe("How many levels deep, 3 by default."),
        contains: z.string().optional().describe("Only return script sources containing this text."),
      },
      Run: async (Input: { path?: string; depth?: number; contains?: string }) => ({content: [{
        type: "text",
        text: ReadReport(await Reach("read", {
          path: Input.path || "game",
          depth: Input.depth,
          contains: Input.contains,
        })),
      }]}),
    },
    {
      Name: "hidden",
      Description: "Read properties Roblox hides from plugins and scripts, which properties and execute cannot see: Workspace's streaming settings (StreamOutBehavior, StreamingTargetRadius, StreamingMinRadius, StreamingIntegrityMode, ModelStreamingBehavior), its physics, avatar and replication settings, Lighting.Technology, and hidden properties on any other instance. Use this instead of assuming what they are set to. Claudio reads them from a copy of the place that Studio writes when a test server starts. That copy is reused for 30 minutes unless fresh is true; making a new one briefly starts and stops a server-only test, which takes up to a minute and cannot happen while a playtest is running. Only the user can change these properties, in Studio's Properties panel.",
      Schema: {
        path: z.string().optional().describe("Full path of the instance, such as Workspace or Lighting. Workspace by default."),
        names: z.array(z.string()).optional().describe("Only these properties. All of them by default."),
        fresh: z.boolean().optional().describe("Make a new copy of the place first, to pick up changes the user made in the last 30 minutes."),
      },
      Run: async (Input: { path?: string; names?: string[]; fresh?: boolean }) => ({content: [{
        type: "text",
        text: await ReadHiddenProperties(Input.path || "Workspace", Input.names, Input.fresh === true),
      }]}),
    },
    {
      Name: "properties",
      Description: "Read an instance's properties, listing every property its class actually has and naming any that could not be read, so a missing one is never mistaken for an unset one.",
      Schema: {
        path: z.string().describe("Full instance path."),
        names: z.array(z.string()).optional().describe("Only these properties. Omit for all of them."),
      },
      Run: async (Input: { path: string; names?: string[] }) => ({content: [{
        type: "text",
        text: PropertyReport(await Reach("properties", {
          path: Input.path,
          names: Input.names,
        })),
      }]}),
    },
    {
      Name: "opencloud",
      Description: "Call Roblox's Open Cloud web API at apis.roblox.com with the user's saved API key, for anything outside the open place: data stores and ordered data stores, memory stores, messaging, publishing places, universe and place settings, badges, game passes, developer products, assets, and more. Give the path, such as /cloud/v2/universes/{universeId}/data-stores, taking the universe and place ids from the studio_place note. Claudio adds the key itself and you never see it. Writes act on the live experience, so read first and say what a write will change before making it. A 401 or 403 means the key lacks that permission or experience. Monetization and badges: game passes are POST or PATCH /game-passes/v1/universes/{universeId}/game-passes[/{id}] and GET .../game-passes/creator; developer products are POST or PATCH /developer-products/v2/universes/{universeId}/developer-products[/{id}] and GET .../developer-products/creator; badges are POST /legacy-badges/v1/universes/{universeId}/badges and PATCH /legacy-badges/v1/badges/{id}. These take form fields, not JSON: game passes and products take name (required), description, price, isForSale, isRegionalPricingEnabled, and an imageFile file; badges take name, description, isActive, paymentSourceType, expectedCost, and a files file for the icon. Badge creation never spends Robux on its own: Claudio sends expectedCost 0, so Roblox refuses a badge that would cost anything. Only if the user clearly asks to pay, send expectedCost with the exact amount; the user then approves that amount in a Windows dialog before anything is spent.",
      Schema: {
        method: z.enum(["GET", "POST", "PATCH", "PUT", "DELETE"]).optional().describe("HTTP method. GET by default."),
        path: z.string().describe("Path under https://apis.roblox.com, such as /cloud/v2/universes/123/data-stores, or a full https://apis.roblox.com address."),
        query: z.record(z.union([z.string(), z.number(), z.boolean()])).optional().describe("Query parameters, such as maxPageSize or pageToken."),
        body: z.any().optional().describe("Request body. Objects are sent as JSON; a string is sent as it is."),
        contentType: z.string().optional().describe("Content type for a string body, such as application/octet-stream."),
        form: z.record(z.union([z.string(), z.number(), z.boolean()])).optional().describe("Send the body as multipart form fields instead, such as Name, Description and Price."),
        files: z.record(z.string()).optional().describe("Files to upload in the form, as field name to full local path, such as an icon PNG."),
      },
      Run: async (Input: { method?: string; path: string; query?: Record<string, string | number | boolean>; body?: unknown; contentType?: string; form?: Record<string, string | number | boolean>; files?: Record<string, string> }) => ({content: [{
        type: "text",
        text: await CallOpenCloud(Input),
      }]}),
    },
    {
      Name: "api",
      Description: "Ask the running engine about the Roblox API: a class's properties, methods and events with full signatures, parameter names, return types, what it inherits and what inherits from it, which members are deprecated or read only, and what security each needs. This is the version of Roblox actually installed, so prefer it over remembering an API or reading documentation that may describe a different version. Narrow with member for one member, search to find a class, enum or member by name, or enumName for an enum's items. Pass deprecated to list only the members you should stop using.",
      Schema: {
        query: z.string().optional().describe("Anything to look up: a class such as Lighting, a member as Class.Member such as UserInputService.GetMouseDelta, or text to search for."),
        className: z.string().optional().describe("Class to describe, such as Lighting, or Class.Member for one member. Leave out everything to list every class."),
        member: z.string().optional().describe("Only this member of the class."),
        search: z.string().optional().describe("Find a class or enum whose name contains this. Pass className too to search that class's members."),
        enumName: z.string().optional().describe("An enum to list the items of, such as Material."),
        inherited: z.boolean().optional().describe("Include the members every instance has, such as Name and Destroy, which are left out by default."),
        deprecated: z.boolean().optional().describe("Only list members that are deprecated."),
      },
      Run: async (Input: { query?: string; className?: string; member?: string; search?: string; enumName?: string; inherited?: boolean; deprecated?: boolean }) => {
        const Named = (Input.className || Input.query || "").trim();
        const [Class, Member] = Named.includes(".") ? Named.split(".", 2) : [Named, Input.member];
        const Asked = {
          className: Class || undefined,
          member: Member || undefined,
          search: Input.search,
          enumName: Input.enumName,
          inherited: Input.inherited === true,
          deprecated: Input.deprecated === true,
        };
        const Answer: any = await Reach("api", Asked);

        if (Input.query && !Input.className && !Named.includes(".") && Answer && typeof Answer.error === "string") {
          return {content: [{
            type: "text",
            text: ApiReport(await Reach("api", {...Asked, className: undefined, search: Named})),
          }]};
        }

        return {content: [{
          type: "text",
          text: ApiReport(Answer),
        }]};
      },
    },
    {
      Name: "modify",
      Description: "Change the place with one undo step: set properties, create, delete, rename or reparent. Prefer this over writing a script for a change this can express, because the arguments are checked and the change is reversible.",
      Schema: {
        action: z.enum(["set", "create", "delete", "rename", "reparent"]),
        path: z.string().optional().describe("The instance to act on."),
        parent: z.string().optional().describe("Parent path, for create and reparent."),
        className: z.string().optional().describe("Class to create."),
        name: z.string().optional().describe("Name to give it, for create and rename."),
        properties: z.record(z.any()).optional().describe("Property names and values, for set and create."),
        undoName: z.string().optional().describe("What the undo step should be called."),
      },
      Run: async (Input: { action: "set" | "create" | "delete" | "rename" | "reparent"; path?: string; parent?: string; className?: string; name?: string; properties?: Record<string, unknown>; undoName?: string }) => ({content: [{
        type: "text",
        text: Said(await Reach("modify", Input),"Studio did not say what happened."),
      }]}),
    },
    {
      Name: "render",
      Description: "Render a part, model or folder to a picture like a product shot, at any angle, with a transparent background, a solid colour, or the real scene behind it. Use it when the user asks to see or export how something looks from a particular side, or for a clean picture of an object on its own. Give view for a named side, or yaw and pitch in degrees to orbit around it: yaw 0 looks at its front, 90 its left side, 180 its back, and pitch 90 looks straight down. The camera fits the object tightly; distance above 1 backs away and below 1 moves in. Everything else is hidden unless isolate is false, and the camera, lighting and selection are always put back. The picture is saved as a PNG and its path returned.",
      Schema: {
        path: z.string().describe("The part, model or folder to render, such as Workspace.Car."),
        view: z.enum(["front", "back", "left", "right", "top", "bottom", "three-quarter"]).optional().describe("A named side to look from. Overrides yaw and pitch when they are left out."),
        yaw: z.number().optional().describe("Degrees around the object, measured from its front. 35 by default."),
        pitch: z.number().optional().describe("Degrees above the object, from -90 below to 90 above. 25 by default."),
        distance: z.number().optional().describe("How far the camera sits, as a multiple of the tight fit. 1 by default."),
        fov: z.number().optional().describe("Field of view in degrees. 30 by default; lower flattens perspective."),
        size: z.number().optional().describe("Output width and height in screen pixels, 512 by default, up to the viewport's height."),
        background: z.string().optional().describe("transparent (the default), scene to keep the real surroundings, or a hex colour such as #202020."),
        isolate: z.boolean().optional().describe("Hide every other part while rendering. True by default."),
        lighting: z.enum(["scene", "studio"]).optional().describe("scene keeps the place's lighting; studio uses flat, even lighting that shows the object clearly."),
        file: z.string().optional().describe("Where to save the PNG. Defaults to a file in the user's Claudio renders folder."),
      },
      Run: async (Input: { path: string; view?: string; yaw?: number; pitch?: number; distance?: number; fov?: number; size?: number; background?: string; isolate?: boolean; lighting?: string; file?: string }) => {
        const Rendered: { error?: string; width: number; height: number; pixels: string; text: string } | null = await Reach("render", Input, 120);

        if (!Rendered || Rendered.error) {
          return {content: [{
            type: "text",
            text: (Rendered && Rendered.error) || "Studio did not answer.",
          }]};
        }

        const { EncodePixels } = await import("./Capture.js");
        const Made = EncodePixels(Rendered.width, Rendered.height, Rendered.pixels) as { error?: string; data: string };

        if (Made.error) {
          return {content: [{
            type: "text",
            text: Made.error,
          }]};
        }

        const Saved = Input.file || path.join(os.homedir(), ".claudio", "renders", `render-${new Date().toISOString().replace(/[:.]/g, "-")}.png`);
        let Note = `, saved to ${Saved}`;

        try {
          fs.mkdirSync(path.dirname(Saved), {recursive: true});
          fs.writeFileSync(Saved, Buffer.from(Made.data, "base64"));
        } catch (Trouble) {
          Note = `, but could not save to ${Saved}: ${(Trouble as Error).message}`;
        }

        return {content: [
          {
            type: "image",
            data: Made.data,
            mimeType: "image/png",
          },
          {
            type: "text",
            text: `${Rendered.text}${Note}`,
          },
        ]};
      },
    },
    {
      Name: "capture",
      Description: "Take a picture of Studio. `of` picks what to capture: `viewport` is the rendered 3D view and the default; `window` is the whole Studio window as the user sees it, at true colours. To look at a plugin's own interface use `of: window` with `widget` set to part of that panel's title, and the picture is cropped to exactly that panel wherever it is docked. Give `around` an instance path to crop the viewport tightly to a part, model or on screen GuiObject, `path` to point the camera at something first, or `x`, `y`, `width` and `height` to crop by hand. The camera is always put back where it was.",
      Schema: {
        of: z.enum(["viewport", "window"]).optional().describe("What to capture. viewport by default."),
        window: z.string().optional().describe("Part of a Studio window title to capture instead of the main one, for a panel floated out of Studio. Only for of window."),
        widget: z.string().optional().describe("Part of a plugin panel's title, such as Claudio. The window capture is cropped to that panel. Only for of window."),
        around: z.string().optional().describe("Instance to crop tightly around, such as Workspace.Model or a GuiObject path."),
        padding: z.number().optional().describe("Pixels of margin around it, 8 by default."),
        path: z.string().optional().describe("Instance to frame the camera on before shooting."),
        x: z.number().optional().describe("Left edge of the region, in pixels from the left of the Studio window."),
        y: z.number().optional().describe("Top edge of the region."),
        width: z.number().optional().describe("Region width. Give width and height together to crop."),
        height: z.number().optional().describe("Region height."),
        file: z.string().optional().describe("Also save the picture to this path as a PNG, for comparing pixels or keeping a record."),
      },
      Run: async (Input: { of?: "viewport" | "window"; window?: string; widget?: string; around?: string; padding?: number; path?: string; x?: number; y?: number; width?: number; height?: number; file?: string }) => {
        const Picture = (Data: string, Text: string): ToolAnswer => {
          if (Input.file) {
            try {
              fs.writeFileSync(Input.file, Buffer.from(Data, "base64"));
              Text += `, saved to ${Input.file}`;
            } catch (Trouble) {
              Text += `, but could not save to ${Input.file}: ${(Trouble as Error).message}`;
            }
          }

          return {content: [
            {
              type: "image",
              data: Data,
              mimeType: "image/png",
            },
            {
              type: "text",
              text: Text,
            },
          ]};
        };

        if (Input.of === "window") {
          const { CaptureWindow, CropToMarker } = await import("./Window.js");
          const Marked: { error?: string; title: string; width: number; height: number } | null = Input.widget ? await Reach("mark", {widget: Input.widget}) : null;

          if (Marked && Marked.error) {
            return {content: [{
              type: "text",
              text: Marked.error,
            }]};
          }

          let Taken: { error?: string; data: string; title: string; width: number; height: number };

          try {
            Taken = await CaptureWindow(Input.window, Marked ? {} : {
              x: Input.x,
              y: Input.y,
              width: Input.width,
              height: Input.height,
            }) as typeof Taken;
          } finally {
            if (Marked) {
              await Reach("unmark", {});
            }
          }

          if (Taken.error) {
            return {content: [{
              type: "text",
              text: Taken.error,
            }]};
          }

          if (!Marked) {
            return Picture(Taken.data, `${Taken.width}x${Taken.height} of the window "${Taken.title}"${Input.width && Input.height ? `, cropped at ${Input.x || 0}, ${Input.y || 0}` : ""}`);
          }

          const Cropped = CropToMarker(Taken.data, Marked.width, Marked.height) as { error?: string; data: string; width: number; height: number; x: number; y: number };

          if (Cropped.error) {
            return {content: [{
              type: "text",
              text: Cropped.error,
            }]};
          }

          return Picture(Cropped.data, `${Cropped.width}x${Cropped.height} of the "${Marked.title}" panel, at ${Cropped.x}, ${Cropped.y} in the window "${Taken.title}"`);
        }

        const { EncodePixels } = await import("./Capture.js");

        let Framed: { error?: string; framed?: string; restore?: boolean } | null = null;

        if (Input.path) {
          Framed = await Reach("frame", {path: Input.path});

          if (Framed && Framed.error) {
            return {content: [{
              type: "text",
              text: Framed.error,
            }]};
          }
        }

        const Shot: { error?: string; width: number; height: number; pixels: string; viewport: string; around?: string } | null = await Reach("shoot",{
          x: Input.x,
          y: Input.y,
          width: Input.width,
          height: Input.height,
          around: Input.around,
          padding: Input.padding,
        });

        if ((!Shot || Shot.error) && !Input.around && !(Input.width && Input.height)) {
          const { CaptureWindow } = await import("./Window.js");
          const Taken = await CaptureWindow(undefined, {}) as { error?: string; data: string; title: string; width: number; height: number };

          if (Framed && Framed.restore) {
            await Reach("frame", {restore: true});
          }

          if (!Taken.error) {
            return Picture(Taken.data, `${Taken.width}x${Taken.height} of the window "${Taken.title}", because the viewport capture failed (${(Shot && Shot.error) || "Studio did not answer"}). During a playtest the editor's viewport is not what is on screen, so the whole window is the reliable view`);
          }
        }

        if (Framed && Framed.restore) {
          await Reach("frame", {restore: true});
        }

        if (!Shot || Shot.error) {
          return {content: [{
            type: "text",
            text: (Shot && Shot.error) || "Studio did not answer.",
          }]};
        }

        const Made = EncodePixels(Shot.width, Shot.height, Shot.pixels) as { error?: string; data: string };

        if (Made.error) {
          return {content: [{
            type: "text",
            text: Made.error,
          }]};
        }

        return Picture(Made.data, `${Shot.width}x${Shot.height} of the ${Shot.viewport} viewport${Shot.around ? `, cropped to ${Shot.around}` : ""}${Framed && Framed.framed ? `, framed on ${Framed.framed}` : ""}`);
      },
    },
    {
      Name: "execute",
      Description: ExecuteDescription,
      Schema: {
        code: z.string().describe("The Luau to run. Return a value to get it back."),
        target: z.enum(["edit", "server", "client"]).optional().describe("Where to run it. edit is the editor itself and the default; server and client are the running play session and need one to be open."),
        readOnly: z.boolean().optional().describe("Set when the script only reads, so no undo step is recorded. Only meaningful in edit."),
        undoName: z.string().optional().describe("What the undo step should be called, such as \"Rename the doors\"."),
        timeout: z.number().optional().describe("How long to wait, in seconds, when the code is expected to take a while. Five minutes by default, thirty at most."),
        player: z.string().optional().describe("Which client to run on when target is client: a player's name, or their number in join order starting at 1. Defaults to the first player."),
        within: z.string().optional().describe("Path of a ModuleScript to run inside: the code runs after a fresh copy of the module's body, above its final return, so its private locals and functions are in scope to call and test. The copy is separate, so the real module's state is untouched, and script refers to the copy. The module's top-level code runs first, so one that waits on something only present in a playtest will wait until the timeout in edit; set a short timeout or run it in a session."),
      },
      Run: async (Input: { code: string; target?: "edit" | "server" | "client"; readOnly?: boolean; undoName?: string; timeout?: number; player?: string; within?: string }) => {
        const Where = Input.target || "edit";

        if (Where !== "edit") {
          const Missing = await NeedsSession("No play session is reachable. Start one with the playtest tool, or from the toolbar, and give it a moment to connect.");

          if (Missing) {
            return {content: [{
              type: "text",
              text: Missing,
            }]};
          }
        }

        const Sent = {
          code: Input.code,
          target: Where,
          readOnly: Input.readOnly === true,
          undoName: Input.undoName,
          player: Input.player,
          within: Input.within,
        };
        const Found: ExecuteAnswer = await ReachIn(Where === "edit" ? "edit" : "server", "execute", Sent, Input.timeout);

        return {content: [{
          type: "text",
          text: ExecuteReport(Found),
        }]};
      },
    },
    {
      Name: "input",
      Description: InputDescription,
      Schema: {
        action: z.enum(["press", "click", "type", "key", "hover", "scroll", "drag", "gamepad"]).describe("What to send. click hits a point given by x and y instead of a path. gamepad presses an input on a real emulated gamepad, through Studio's Controller Emulator panel."),
        pad: z.enum(PadInputs).optional().describe("For gamepad: the button, d-pad direction or stick push to hold for hold seconds, 0.1 by default. The game sees a genuine connected gamepad, so GamepadEnabled, gamepad UI selection and gamepad bindings all respond. Start opens Roblox's own menu, which then takes all gamepad input until B closes it. Needs the user to have the Controller Emulator panel open and visible; the first press takes up to a minute while Claudio finds the panel."),
        window: z.boolean().optional().describe("For click: x and y are pixels in a capture of the Studio window, and the click is sent to that window as a real mouse click instead of simulated game input. This reaches CoreGui, such as purchase and prompt windows, which refuse simulated input, and works without a play session."),
        path: z.string().optional().describe("Full instance path of the GuiObject for press, hover, scroll and drag."),
        text: z.string().optional().describe("The text to type, for type."),
        key: z.string().optional().describe("KeyCode name to press and release, such as Return or E, for key."),
        amount: z.number().optional().describe("Wheel amount for scroll, negative scrolls down. Defaults to -1."),
        to: z.string().optional().describe("Full instance path to drag onto, for drag."),
        x: z.number().optional().describe("For click, the point's x in AbsolutePosition space, or in window capture pixels with window. For drag, pixels to move sideways when there is no to path."),
        y: z.number().optional().describe("For click, the point's y. For drag, pixels to move down when there is no to path."),
        button: z.enum(["left", "right", "middle"]).optional().describe("Which mouse button a drag holds. Defaults to left."),
        hold: z.number().optional().describe("Seconds to keep the button down at the end of a drag before releasing, or to hold a gamepad input, up to 5."),
        player: z.string().optional().describe("Which client to send it to: a player's name, or their number in join order starting at 1. Defaults to the first player."),
      },
      Run: async (Input: { action: "press" | "click" | "type" | "key" | "hover" | "scroll" | "drag" | "gamepad"; pad?: string; window?: boolean; path?: string; text?: string; key?: string; amount?: number; to?: string; x?: number; y?: number; button?: "left" | "right" | "middle"; hold?: number; player?: string }) => {
        if (Input.action === "type" && !Input.text) {
          return {content: [{
            type: "text",
            text: "Typing needs text.",
          }]};
        }

        if (Input.action === "key" && !Input.key) {
          return {content: [{
            type: "text",
            text: "A key press needs key, the name of a KeyCode such as Return or E.",
          }]};
        }

        if (Input.action === "click" && (Input.x === undefined || Input.y === undefined)) {
          return {content: [{
            type: "text",
            text: "A click needs x and y.",
          }]};
        }

        if (Input.action === "gamepad") {
          return {content: [{
            type: "text",
            text: Input.pad ? await PressPad(Input.pad, Input.hold ?? 0.1) : "A gamepad press needs pad, such as A, DPadUp or LeftStickUp.",
          }]};
        }

        if (Input.action === "click" && Input.window === true) {
          const { ClickWindow } = await import("./Window.js");

          return {content: [{
            type: "text",
            text: await ClickWindow(Input.x as number, Input.y as number, Input.button || "left"),
          }]};
        }

        if (Input.action !== "type" && Input.action !== "key" && Input.action !== "drag" && Input.action !== "click" && !Input.path) {
          return {content: [{
            type: "text",
            text: `${Input.action} needs path, the full instance path of the GuiObject to act on.`,
          }]};
        }

        if (Input.action === "drag" && !Input.to && Input.x === undefined && Input.y === undefined) {
          return {content: [{
            type: "text",
            text: "A drag needs somewhere to go: to for another GuiObject, or x and y to move by.",
          }]};
        }

        const Missing = await NeedsSession("No play session is reachable, and input has to happen on the client where the interface lives. Start one with the playtest tool and give it a moment to connect.");

        if (Missing) {
          return {content: [{
            type: "text",
            text: Missing,
          }]};
        }

        return {content: [{
          type: "text",
          text: Said(await ReachIn("server", "input", {
            action: Input.action,
            path: Input.path,
            text: Input.text,
            key: Input.key,
            amount: Input.amount,
            to: Input.to,
            x: Input.x,
            y: Input.y,
            button: Input.button,
            hold: Input.hold,
            player: Input.player,
          }), "Studio did not say what happened."),
        }]};
      },
    },
    {
      Name: "playtest",
      Description: PlaytestDescription,
      Schema: {
        action: z.enum(["start", "stop", "status", "players", "quality"]).describe("quality sets the playtest's graphics level from 1 to 10, as a player on a weaker or stronger device would see it; capture the window to see the result. Stopping the playtest puts Studio's graphics level back to automatic. " + "What to do. Use status to find out what is happening before changing it; during a multiplayer test it also says how many players are in. The players action adds players, so never use it just to count them."),
        mode: z.enum(["play", "run", "multiplayer"]).optional().describe("How to start it. play gives a character, run simulates without one, multiplayer starts a server with several clients. Defaults to play."),
        players: z.number().optional().describe("How many players, for multiplayer starts and for the players action."),
        level: z.number().optional().describe("Graphics level from 1, the lowest, to 10, the highest, for the quality action."),
        player: z.string().optional().describe("Which client the quality action applies to: a player's name, or their number in join order. Defaults to the first player."),
        force: z.boolean().optional().describe("Start a multiplayer test or add players even when the memory check says the machine cannot carry it."),
      },
      Run: async (Input: { action: "start" | "stop" | "status" | "players" | "quality"; mode?: "play" | "run" | "multiplayer"; players?: number; force?: boolean; level?: number; player?: string }, Extra?: unknown) => {
        const Signal = (Extra as {signal?: AbortSignal} | undefined)?.signal;

        if (Input.action === "quality") {
          const Missing = await NeedsSession("Setting the graphics level needs a running playtest with a client. Start one first.");

          if (Missing) {
            return {content: [{
              type: "text",
              text: Missing,
            }]};
          }

          const Level = Math.min(10, Math.max(1, Math.round(Input.level || 5)));

          QualityChanged = true;
          const Set: { error?: string; now?: string } | null = await ReachIn("server", "quality", {level: Level, player: Input.player});

          if (!Set || Set.error) {
            return {content: [{
              type: "text",
              text: (Set && Set.error) || "The client did not answer.",
            }]};
          }

          return {content: [{
            type: "text",
            text: `The playtest now renders at graphics level ${Level} (${Set.now}). Capture the window to see it. Stopping the playtest puts Studio back to automatic.`,
          }]};
        }
        const Reachable = await LiveSession();
        const Adding = Input.action === "players" ? Math.max(1, Math.floor(Input.players || 1)) : (Input.action === "start" && Input.mode === "multiplayer" ? Math.max(2, Math.floor(Input.players || 2)) : 0);
        const Refused = Adding > 0 && Input.force !== true ? await Headroom(Adding, Input.action === "start") : null;

        if (Refused) {
          return {content: [{
            type: "text",
            text: Refused,
          }]};
        }

        if (Reachable && (Input.action === "stop" || Input.action === "players")) {
          const Release = Input.action === "stop" ? await QuietFlash(30) : () => {};
          const Answer = Said(await ReachIn("server", "playtest", {
            action: Input.action,
            players: Input.players,
          }, Input.action === "stop" ? 20 : undefined), "The session did not say what happened.");

          if (Input.action === "stop" && !Answer.startsWith("Playtest stopped")) {
            setTimeout(Release, 12000);

            return {content: [{
              type: "text",
              text: await ForceStop(`The session did not stop itself: ${Answer}`),
            }]};
          }

          setTimeout(Release, 12000);

          return {content: [{
            type: "text",
            text: Input.action === "players" && Answer.startsWith("Players went") ? Answer + await WaitUntilLoaded((Reachable.Players || 0) + Adding, Signal) : (Input.action === "stop" && Answer.startsWith("Playtest stopped") ? Answer + await WaitUntilStopped(Signal) : Answer),
          }]};
        }

        if (Reachable && Input.action === "start") {
          return {content: [{
            type: "text",
            text: "A playtest is already running and its session is reachable, so it was left alone. Stop it first if you want a fresh run.",
          }]};
        }

        if (Reachable && Input.action === "status") {
          return {content: [{
            type: "text",
            text: `A playtest is running${Reachable.Players === null ? "" : ` with ${Reachable.Players} player${Reachable.Players === 1 ? "" : "s"} in it`}, so stop and players are available.`,
          }]};
        }

        const Release = Input.action === "start" || Input.action === "stop" ? await QuietFlash(60) : () => {};
        const Found: { error?: string; text?: string; relay?: string; players?: number } | null = await Reach("playtest", {
          action: Input.action,
          mode: Input.mode,
          players: Input.players,
        });

        setTimeout(Release, 12000);

        if (Found && Found.relay) {
          const Missing = await NeedsSession(`Studio only allows ${Found.relay} from inside the running session, and the session is not reachable. It needs Allow HTTP Requests turned on in Game Settings before the playtest starts, otherwise stop it from Studio's toolbar.`);

          if (Missing && Found.relay === "stop") {
            return {content: [{
              type: "text",
              text: await ForceStop("The session is not reachable."),
            }]};
          }

          if (Missing) {
            return {content: [{
              type: "text",
              text: Missing,
            }]};
          }

          const Relayed = Said(await ReachIn("server", "playtest", {
            action: Found.relay,
            players: Found.players,
          }), "The session did not say what happened.");

          return {content: [{
            type: "text",
            text: Found.relay === "stop" && Relayed.startsWith("Playtest stopped") ? Relayed + await WaitUntilStopped(Signal) : Relayed,
          }]};
        }

        const Answer = Said(Found, "Studio did not say what happened.");

        return {content: [{
          type: "text",
          text: Input.action === "start" && Found && !Found.error ? Answer + await WaitUntilLoaded(Input.mode === "run" ? 0 : Math.max(1, Adding), Signal) : Answer,
        }]};
      },
    },
    {
      Name: "device",
      Description: "Simulate a device in the editor viewport, so a phone or tablet layout can be checked without one. status says what is running and lists the profiles Studio knows, set applies a device and any of orientation, width and height, density or scaling, stop returns the viewport to the editor's own, and network shapes a running playtest's latency, jitter and packet loss.",
      Schema: {
        action: z.enum(["status", "set", "stop", "network"]).optional().describe("Defaults to status."),
        device: z.string().optional().describe("A device profile id, such as iphone_16. status lists them."),
        orientation: z.string().optional().describe("A ScreenOrientation name, such as LandscapeLeft."),
        width: z.number().optional().describe("Viewport width in pixels. Give width and height together."),
        height: z.number().optional().describe("Viewport height in pixels."),
        density: z.number().optional().describe("Pixel density, above zero."),
        scaling: z.string().optional().describe("A DeviceSimulatorScalingMode name."),
        network: z.enum(["status", "great", "good", "poor", "off"]).optional().describe("Which network conditions to apply, for the network action."),
      },
      Run: async (Input: { action?: "status" | "set" | "stop" | "network"; device?: string; orientation?: string; width?: number; height?: number; density?: number; scaling?: string; network?: "status" | "great" | "good" | "poor" | "off" }) => ({content: [{
        type: "text",
        text: Said(await Reach("device", Input),"Studio did not say what happened."),
      }]}),
    },
    {
      Name: "layout",
      Description: "Measure a GuiObject: its size and position, how big it is against its own ScreenGui rather than the viewport, and whether anything hides, clips or pushes it off screen. Use this before believing UI is broken on a simulated device.",
      Schema: {path: z.string().describe("Full instance path of the GuiObject to measure.")},
      Run: async (Input: { path: string }) => ({content: [{
        type: "text",
        text: Said(await Reach("layout",{path: Input.path}), "Studio did not say what happened."),
      }]}),
    },
    {
      Name: "profile",
      Description: "Measure what the place is spending. memory breaks live memory down by tag, largest first. Point it at the session with target when a playtest is running, because the editor and the session use separate memory.",
      Schema: {
        action: z.enum(["memory"]).optional().describe("What to measure. Defaults to memory."),
        least: z.number().optional().describe("Leave out tags smaller than this many MB. One by default."),
        target: z.enum(["edit", "server"]).optional().describe("Whose memory to read. edit is the editor and the default."),
      },
      Run: async (Input: { action?: "memory"; least?: number; target?: "edit" | "server" }) => {
        const Where = Input.target || "edit";
        const Sent = {least: Input.least};
        const Found: SaidAnswer = Where === "edit" ? await Reach("memory", Sent) : await ReachIn("server", "memory", Sent);

        return {content: [{
          type: "text",
          text: Said(Found, "Studio did not say what happened."),
        }]};
      },
    },
    {
      Name: "changes",
      Description: "List what has actually changed in the place since the turn started, so you can confirm an edit landed and catch anything that changed by accident. Claudio's own scaffolding is left out.",
      Schema: {limit: z.number().optional().describe("How many to return, forty by default.")},
      Run: async (Input: { limit?: number }) => {
        const Found: { error?: string; text?: string; lines?: string[] } | null = await Reach("changes", {limit: Input.limit});

        if (Found && Found.lines) {
          return {content: [{
            type: "text",
            text: Found.lines.join("\n"),
          }]};
        }

        return {content: [{
          type: "text",
          text: Said(Found, "Studio did not say what happened."),
        }]};
      },
    },
    {
      Name: "find",
      Description: "Search every script in the place, or under a path, for a piece of text. Returns each match as a path, a line number and the line, so it can be read without opening anything.",
      Schema: {
        text: z.string().describe("The text to look for. Case is ignored."),
        path: z.string().optional().describe("Only search under here, such as ServerScriptService."),
        limit: z.number().optional().describe("How many matches to return, forty by default."),
      },
      Run: async (Input: { text: string; path?: string; limit?: number }) => ({content: [{
        type: "text",
        text: FindReport(await Reach("find", {
          text: Input.text,
          path: Input.path,
          limit: Input.limit,
        })),
      }]}),
    },
    {
      Name: "source",
      Description: "Read or change a script's source by line. get returns a numbered window, set replaces the whole thing, and insert, replace and delete work on line ranges. Every change is one undo step. Read a script before editing it, because a stale line range edits the wrong lines instead of failing. Prefer this over rewriting a whole script when only part of it changes.",
      Schema: {
        path: z.string().describe("The script's full instance path."),
        action: z.enum(["get", "set", "insert", "replace", "delete"]).optional().describe("What to do. Defaults to get."),
        from: z.number().optional().describe("First line, counting from one."),
        to: z.number().optional().describe("Last line, for get, replace and delete."),
        text: z.string().optional().describe("The new source, for set, insert and replace."),
        undoName: z.string().optional().describe("What the undo step should be called."),
      },
      Run: async (Input: { path: string; action?: "get" | "set" | "insert" | "replace" | "delete"; from?: number; to?: number; text?: string; undoName?: string }) => ({content: [{
        type: "text",
        text: SourceReport(await Reach("source", Input)),
      }]}),
    },
    {
      Name: "select",
      Description: "Read or set what is selected in Studio. Selecting is how you show the user what you are talking about, and reading it is how you find out what they mean by \"this\".",
      Schema: {paths: z.array(z.string()).optional().describe("Instance paths to select. Leave out to read the current selection.")},
      Run: async (Input: { paths?: string[] }) => ({content: [{
        type: "text",
        text: SelectReport(await Reach("select", {paths: Input.paths})),
      }]}),
    },
    {
      Name: "history",
      Description: "Undo or redo a step in Studio, or ask what is available. Use this to take back a change you just made rather than trying to write the reverse of it. mark names a point before something risky and restore undoes back to it.",
      Schema: {
        action: z.enum(["status", "undo", "redo", "mark", "restore"]).optional().describe("Defaults to status."),
        name: z.string().optional().describe("What to call the mark, for mark and restore."),
      },
      Run: async (Input: { action?: "status" | "undo" | "redo" | "mark" | "restore"; name?: string }) => ({content: [{
        type: "text",
        text: Said(await Reach("history",{
          action: Input.action,
          name: Input.name,
        }), "Studio did not say what happened."),
      }]}),
    },
    {
      Name: "rbxm",
      Description: "Save instances to an rbxm file on disk, load one back into the place, or build one from a folder of source files. Give paths and file to save, file and path to load it under, or folder and file to build. Building never touches the open place: Studio assembles the instances on the side and only the file is written. Folders follow Rojo's layout: init.luau makes the folder itself a script, name.server.luau is a Script, name.client.luau a LocalScript, name.luau a ModuleScript, .legacy and .local are a Script and a LocalScript, name.txt is a StringValue, name.rbxm is merged in as it is, and name.meta.json or init.meta.json can set className, properties (plain values, enums by name) and attributes.",
      Schema: {
        file: z.string().describe("Where the file lives on disk."),
        folder: z.string().optional().describe("A folder of source files to build into the file."),
        name: z.string().optional().describe("What to call the root instance when building. Defaults to the folder's name."),
        paths: z.array(z.string()).optional().describe("Instances to save. Give these to save, leave them out to load."),
        path: z.string().optional().describe("Where to put what is loaded, such as Workspace."),
        undoName: z.string().optional().describe("What the undo step should be called, when loading."),
      },
      Run: async (Input: { file: string; folder?: string; name?: string; paths?: string[]; path?: string; undoName?: string }) => {
        let Tree: DiskNode | undefined;

        if (Input.folder) {
          try {
            Tree = ReadDiskTree(Input.folder, Input.name || path.basename(path.resolve(Input.folder)));
          } catch (Trouble) {
            return {content: [{
              type: "text",
              text: `Built nothing, because the folder could not be read: ${(Trouble as Error).message}`,
            }]};
          }
        }

        if (Tree || (Input.paths && Input.paths.length > 0)) {
          const Found: { error?: string; text?: string; base64?: string; count?: number } | null = await Reach("rbxm", {paths: Input.paths, tree: Tree});

          if (!Found || Found.error || !Found.base64) {
            return {content: [{
              type: "text",
              text: Said(Found, "Studio did not say what happened."),
            }]};
          }

          try {
            fs.writeFileSync(Input.file, Buffer.from(Found.base64, "base64"));
          } catch (Trouble) {
            return {content: [{
              type: "text",
              text: `Saved nothing, because the file could not be written: ${(Trouble as Error).message}`,
            }]};
          }

          return {content: [{
            type: "text",
            text: `Saved ${Found.count} to ${Input.file}.`,
          }]};
        }

        if (!Input.path) {
          return {content: [{
            type: "text",
            text: "Give paths and a file to save, or a file and a path to load.",
          }]};
        }

        let Body: string;

        try {
          Body = fs.readFileSync(Input.file).toString("base64");
        } catch (Trouble) {
          return {content: [{
            type: "text",
            text: `Loaded nothing, because the file could not be read: ${(Trouble as Error).message}`,
          }]};
        }

        return {content: [{
          type: "text",
          text: Said(await Reach("rbxm", {
            base64: Body,
            path: Input.path,
            undoName: Input.undoName,
          }), "Studio did not say what happened."),
        }]};
      },
    },
    {
      Name: "logs",
      Description: "Read the output log of the open place, filtered in Studio so only what you ask for crosses the wire. Use level problems for just warnings and errors, contains to search, and limit to cap how much comes back, which defaults to forty of the most recent. Point it at the session with target when a playtest is running, because the editor and the session keep separate logs.",
      Schema: {
        level: z.enum(["all", "print", "warn", "error", "info", "problems"]).optional().describe("Which kinds to return. problems means warnings and errors."),
        contains: z.string().optional().describe("Only lines containing this text."),
        limit: z.number().optional().describe("How many to return, newest last. Forty by default, two hundred at most."),
        since: z.number().optional().describe("Only entries from the last this many seconds."),
        target: z.enum(["edit", "server"]).optional().describe("Whose log to read. edit is the editor and the default; server is the running play session."),
      },
      Run: async (Input: { level?: "all" | "print" | "warn" | "error" | "info" | "problems"; contains?: string; limit?: number; since?: number; target?: "edit" | "server" }) => {
        const Where = Input.target || "edit";
        const Sent = {
          level: Input.level,
          contains: Input.contains,
          limit: Input.limit,
          since: Input.since,
        };
        const Found: LogAnswer = Where === "edit" ? await Reach("logs", Sent) : await ReachIn("server", "logs", Sent);

        return {content: [{
          type: "text",
          text: LogReport(Found),
        }]};
      },
    },
    {
      Name: "lint",
      Description: LintDescription,
      Schema: {paths: z.array(z.string()).optional().describe("Instance paths to check, such as ServerScriptService.Main. Omit to check the whole place.")},
      Run: async (Input: { paths?: string[] }) => ({content: [{
        type: "text",
        text: LintReport(await Reach("lint", {paths: Input.paths || []})),
      }]}),
    },
  ];
}