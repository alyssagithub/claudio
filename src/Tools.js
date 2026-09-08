import { z } from "zod/v3";
import { ReadReport, PropertyReport, ApiReport, ExecuteReport, FindReport, SourceReport, SelectReport, LogReport, LintReport } from "./Ask.js";

const ExecuteDescription = [
  "Run Luau inside the open place and get back what it returned, what it printed, and where it failed.",
  "target picks where: edit is the editor and the default, server and client are the running play session and need one open.",
  "Changes are recorded as one undo step; pass readOnly when you only want to look.",
  "Set timeout in seconds when the code is expected to take a while, up to thirty minutes; it defaults to five.",
  "Call _G.ClaudioFresh(module) to require past the cache.",
].join(" ");

const PressDescription = [
  "Press a button in the running experience by naming its instance path, rather than by guessing screen coordinates.",
  "Needs a play session with a character.",
  "A press that reaches nothing still reports as sent, so check the place afterwards.",
].join(" ");

const PlaytestDescription = [
  "Start, stop or inspect a playtest of the open place.",
  "Always stop what you started.",
  "Check status first rather than assuming.",
  "This runs without a player character, so LocalPlayer and PlayerGui are not available.",
].join(" ");

const LintDescription = [
  "Check scripts in the open place for analyzer warnings, including scripts nobody has edited.",
  "Pass paths to narrow it, or leave it empty to check everything.",
  "Report what it finds rather than fixing unasked, because pre-existing warnings were already there.",
].join(" ");

function Said(Found, Missing) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  return Found.text || Missing;
}

export function StudioTools(Deps) {
  const { Reach, ReachIn, Presence, RuntimeLive } = Deps;

  async function NeedsSession(What) {
    return (await RuntimeLive()) ? null : What;
  }

  return [
    {
      Name: "instances",
      Description: "Say whether Studio is open and whether the Claudio plugin has checked in. Ask this before assuming nothing is connected, and never open Studio yourself on the strength of an empty answer.",
      Schema: {},
      Run: async () => ({ content: [{ type: "text", text: await Presence() }] }),
    },
    {
      Name: "read",
      Description: "Read a part of the open place in one call: the instance tree under a path, plus the source of scripts in it. Prefer this over walking the tree with separate calls.",
      Schema: {
        path: z.string().optional().describe("Where to start, such as ServerScriptService. Defaults to the whole place."),
        depth: z.number().optional().describe("How many levels deep, 3 by default."),
        contains: z.string().optional().describe("Only return script sources containing this text."),
      },
      Run: async (Input) => ({ content: [{ type: "text", text: ReadReport(await Reach("read", { path: Input.path || "game", depth: Input.depth, contains: Input.contains })) }] }),
    },
    {
      Name: "properties",
      Description: "Read an instance's properties, listing every property its class actually has and naming any that could not be read, so a missing one is never mistaken for an unset one.",
      Schema: {
        path: z.string().describe("Full instance path."),
        names: z.array(z.string()).optional().describe("Only these properties. Omit for all of them."),
      },
      Run: async (Input) => ({ content: [{ type: "text", text: PropertyReport(await Reach("properties", { path: Input.path, names: Input.names })) }] }),
    },
    {
      Name: "api",
      Description: "Ask the running engine about the Roblox API: a class's properties, methods and events with full signatures, parameter names, return types, what it inherits and what inherits from it, which members are deprecated or read only, and what security each needs. This is the version of Roblox actually installed, so prefer it over remembering an API or reading documentation that may describe a different version. Narrow with member for one member, search to find a class, enum or member by name, or enumName for an enum's items. Pass deprecated to list only the members you should stop using.",
      Schema: {
        className: z.string().optional().describe("Class to describe, such as Lighting. Leave out to list every class."),
        member: z.string().optional().describe("Only this member of the class."),
        search: z.string().optional().describe("Find a class or enum whose name contains this. Pass className too to search that class's members."),
        enumName: z.string().optional().describe("An enum to list the items of, such as Material."),
        inherited: z.boolean().optional().describe("Include the members every instance has, such as Name and Destroy, which are left out by default."),
        deprecated: z.boolean().optional().describe("Only list members that are deprecated."),
      },
      Run: async (Input) => ({ content: [{ type: "text", text: ApiReport(await Reach("api", { className: Input.className, member: Input.member, search: Input.search, enumName: Input.enumName, inherited: Input.inherited === true, deprecated: Input.deprecated === true })) }] }),
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
        label: z.string().optional().describe("What the undo step should be called."),
      },
      Run: async (Input) => ({ content: [{ type: "text", text: Said(await Reach("modify", Input), "Studio did not say what happened.") }] }),
    },
    {
      Name: "capture",
      Description: "Take a picture of the Studio viewport. Give around with an instance path to crop tightly to that thing, which works for a part, a model or any on screen GuiObject, and costs a fraction of a whole viewport to look at. Give path to point the camera at something first, or x, y, width and height to crop by hand. The camera is always put back where it was. Plugin windows are not in the viewport, so they cannot be captured this way.",
      Schema: {
        around: z.string().optional().describe("Instance to crop tightly around, such as Workspace.Model or a GuiObject path."),
        padding: z.number().optional().describe("Pixels of margin around it, 8 by default."),
        path: z.string().optional().describe("Instance to frame the camera on before shooting."),
        x: z.number().optional().describe("Left edge of the region, in pixels from the left of the Studio window."),
        y: z.number().optional().describe("Top edge of the region."),
        width: z.number().optional().describe("Region width. Give width and height together to crop."),
        height: z.number().optional().describe("Region height."),
      },
      Run: async (Input) => {
        const { EncodePixels } = await import("./Capture.js");

        let Framed = null;

        if (Input.path) {
          Framed = await Reach("frame", { path: Input.path });

          if (Framed && Framed.error) {
            return { content: [{ type: "text", text: Framed.error }] };
          }
        }

        const Shot = await Reach("shoot", { x: Input.x, y: Input.y, width: Input.width, height: Input.height, around: Input.around, padding: Input.padding });

        if (Framed && Framed.restore) {
          await Reach("frame", { restore: true });
        }

        if (!Shot || Shot.error) {
          return { content: [{ type: "text", text: (Shot && Shot.error) || "Studio did not answer." }] };
        }

        const Made = EncodePixels(Shot.width, Shot.height, Shot.pixels);

        if (Made.error) {
          return { content: [{ type: "text", text: Made.error }] };
        }

        return {
          content: [
            { type: "image", data: Made.data, mimeType: "image/png" },
            { type: "text", text: `${Shot.width}x${Shot.height} of the ${Shot.viewport} viewport${Shot.around ? `, cropped to ${Shot.around}` : ""}${Framed && Framed.framed ? `, framed on ${Framed.framed}` : ""}` },
          ],
        };
      },
    },
    {
      Name: "execute",
      Description: ExecuteDescription,
      Schema: {
        code: z.string().describe("The Luau to run. Return a value to get it back."),
        target: z.enum(["edit", "server", "client"]).optional().describe("Where to run it. edit is the editor itself and the default; server and client are the running play session and need one to be open."),
        readOnly: z.boolean().optional().describe("Set when the script only reads, so no undo step is recorded. Only meaningful in edit."),
        label: z.string().optional().describe("What the undo step should be called, such as \"Rename the doors\"."),
        timeout: z.number().optional().describe("How long to wait, in seconds, when the code is expected to take a while. Five minutes by default, thirty at most."),
      },
      Run: async (Input) => {
        const Where = Input.target || "edit";

        if (Where !== "edit") {
          const Missing = await NeedsSession("No play session is reachable. Start one with the playtest tool, or from the toolbar, and give it a moment to connect.");

          if (Missing) {
            return { content: [{ type: "text", text: Missing }] };
          }
        }

        const Sent = { code: Input.code, target: Where, readOnly: Input.readOnly === true, label: Input.label };
        const Found = await ReachIn(Where === "edit" ? "edit" : "server", "execute", Sent, Input.timeout);

        return { content: [{ type: "text", text: ExecuteReport(Found) }] };
      },
    },
    {
      Name: "press",
      Description: PressDescription,
      Schema: { path: z.string().describe("Full instance path of the GuiObject to press.") },
      Run: async (Input) => {
        const Missing = await NeedsSession("No play session is reachable, and a press has to happen on the client where the interface lives. Start one with the playtest tool and give it a moment to connect.");

        if (Missing) {
          return { content: [{ type: "text", text: Missing }] };
        }

        return { content: [{ type: "text", text: Said(await ReachIn("server", "press", { path: Input.path }), "Studio did not say what happened.") }] };
      },
    },
    {
      Name: "type",
      Description: "Type text into whatever has keyboard focus in the running experience, such as a TextBox you have just pressed. Needs a play session. Check the place afterwards, because typing that reaches nothing still reports as sent.",
      Schema: { text: z.string().describe("The text to type.") },
      Run: async (Input) => {
        const Missing = await NeedsSession("No play session is reachable, and typing has to happen on the client. Start one with the playtest tool.");

        if (Missing) {
          return { content: [{ type: "text", text: Missing }] };
        }

        return { content: [{ type: "text", text: Said(await ReachIn("server", "type", { text: Input.text }), "The session did not say what happened.") }] };
      },
    },
    {
      Name: "playtest",
      Description: PlaytestDescription,
      Schema: {
        action: z.enum(["start", "stop", "status", "players"]).describe("What to do. Use status to find out what is happening before changing it."),
        mode: z.enum(["play", "run", "multiplayer"]).optional().describe("How to start it. play gives a character, run simulates without one, multiplayer starts a server with several clients. Defaults to play."),
        players: z.number().optional().describe("How many players, for multiplayer starts and for the players action."),
      },
      Run: async (Input) => {
        const Found = await Reach("playtest", { action: Input.action, mode: Input.mode, players: Input.players });

        if (Found && Found.relay) {
          const Missing = await NeedsSession(`Studio only allows ${Found.relay} from inside the running session, and the session is not reachable. It needs Allow HTTP Requests turned on in Game Settings before the playtest starts, otherwise stop it from Studio's toolbar.`);

          if (Missing) {
            return { content: [{ type: "text", text: Missing }] };
          }

          return { content: [{ type: "text", text: Said(await ReachIn("server", "playtest", { action: Found.relay, players: Found.players }), "The session did not say what happened.") }] };
        }

        return { content: [{ type: "text", text: Said(Found, "Studio did not say what happened.") }] };
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
      Run: async (Input) => ({ content: [{ type: "text", text: Said(await Reach("device", Input), "Studio did not say what happened.") }] }),
    },
    {
      Name: "layout",
      Description: "Measure a GuiObject: its size and position, how big it is against its own ScreenGui rather than the viewport, and whether anything hides, clips or pushes it off screen. Use this before believing UI is broken on a simulated device.",
      Schema: { path: z.string().describe("Full instance path of the GuiObject to measure.") },
      Run: async (Input) => ({ content: [{ type: "text", text: Said(await Reach("layout", { path: Input.path }), "Studio did not say what happened.") }] }),
    },
    {
      Name: "profile",
      Description: "Measure what the place is spending. memory breaks live memory down by tag, largest first. Point it at the session with target when a playtest is running, because the editor and the session use separate memory.",
      Schema: {
        action: z.enum(["memory"]).optional().describe("What to measure. Defaults to memory."),
        least: z.number().optional().describe("Leave out tags smaller than this many MB. One by default."),
        target: z.enum(["edit", "server"]).optional().describe("Whose memory to read. edit is the editor and the default."),
      },
      Run: async (Input) => {
        const Where = Input.target || "edit";
        const Sent = { least: Input.least };
        const Found = Where === "edit" ? await Reach("memory", Sent) : await ReachIn("server", "memory", Sent);

        return { content: [{ type: "text", text: Said(Found, "Studio did not say what happened.") }] };
      },
    },
    {
      Name: "changes",
      Description: "List what has actually changed in the place since the turn started, so you can confirm an edit landed and catch anything that changed by accident. Claudio's own scaffolding is left out.",
      Schema: { limit: z.number().optional().describe("How many to return, forty by default.") },
      Run: async (Input) => {
        const Found = await Reach("changes", { limit: Input.limit });

        if (Found && Found.lines) {
          return { content: [{ type: "text", text: Found.lines.join("\n") }] };
        }

        return { content: [{ type: "text", text: Said(Found, "Studio did not say what happened.") }] };
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
      Run: async (Input) => ({ content: [{ type: "text", text: FindReport(await Reach("find", { text: Input.text, path: Input.path, limit: Input.limit })) }] }),
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
        label: z.string().optional().describe("What the undo step should be called."),
      },
      Run: async (Input) => ({ content: [{ type: "text", text: SourceReport(await Reach("source", Input)) }] }),
    },
    {
      Name: "select",
      Description: "Read or set what is selected in Studio. Selecting is how you show the user what you are talking about, and reading it is how you find out what they mean by \"this\".",
      Schema: { paths: z.array(z.string()).optional().describe("Instance paths to select. Leave out to read the current selection.") },
      Run: async (Input) => ({ content: [{ type: "text", text: SelectReport(await Reach("select", { paths: Input.paths })) }] }),
    },
    {
      Name: "history",
      Description: "Undo or redo a step in Studio, or ask what is available. Use this to take back a change you just made rather than trying to write the reverse of it. mark names a point before something risky and restore undoes back to it.",
      Schema: {
        action: z.enum(["status", "undo", "redo", "mark", "restore"]).optional().describe("Defaults to status."),
        name: z.string().optional().describe("What to call the mark, for mark and restore."),
      },
      Run: async (Input) => ({ content: [{ type: "text", text: Said(await Reach("history", { action: Input.action, name: Input.name }), "Studio did not say what happened.") }] }),
    },
    {
      Name: "rbxm",
      Description: "Save instances to an rbxm file on disk, or load one back into the place. Give paths and file to save, or file and path to load it under. Use it to keep a copy before something risky, or to move a build between places.",
      Schema: {
        file: z.string().describe("Where the file lives on disk."),
        paths: z.array(z.string()).optional().describe("Instances to save. Give these to save, leave them out to load."),
        path: z.string().optional().describe("Where to put what is loaded, such as Workspace."),
        label: z.string().optional().describe("What the undo step should be called, when loading."),
      },
      Run: async (Input) => {
        const fs = await import("node:fs");

        if (Input.paths && Input.paths.length > 0) {
          const Found = await Reach("rbxm", { paths: Input.paths });

          if (!Found || Found.error || !Found.base64) {
            return { content: [{ type: "text", text: Said(Found, "Studio did not say what happened.") }] };
          }

          try {
            fs.writeFileSync(Input.file, Buffer.from(Found.base64, "base64"));
          } catch (Trouble) {
            return { content: [{ type: "text", text: `Saved nothing, because the file could not be written: ${Trouble.message}` }] };
          }

          return { content: [{ type: "text", text: `Saved ${Found.count} to ${Input.file}.` }] };
        }

        if (!Input.path) {
          return { content: [{ type: "text", text: "Give paths to save, or path to load it under." }] };
        }

        let Body;

        try {
          Body = fs.readFileSync(Input.file).toString("base64");
        } catch (Trouble) {
          return { content: [{ type: "text", text: `Loaded nothing, because the file could not be read: ${Trouble.message}` }] };
        }

        return { content: [{ type: "text", text: Said(await Reach("rbxm", { base64: Body, path: Input.path, label: Input.label }), "Studio did not say what happened.") }] };
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
      Run: async (Input) => {
        const Where = Input.target || "edit";
        const Sent = { level: Input.level, contains: Input.contains, limit: Input.limit, since: Input.since };
        const Found = Where === "edit" ? await Reach("logs", Sent) : await ReachIn("server", "logs", Sent);

        return { content: [{ type: "text", text: LogReport(Found) }] };
      },
    },
    {
      Name: "lint",
      Description: LintDescription,
      Schema: { paths: z.array(z.string()).optional().describe("Instance paths to check, such as ServerScriptService.Main. Omit to check the whole place.") },
      Run: async (Input) => ({ content: [{ type: "text", text: LintReport(await Reach("lint", { paths: Input.paths || [] })) }] }),
    },
  ];
}