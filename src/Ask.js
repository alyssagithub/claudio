import { createSdkMcpServer, tool } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

export const AskServerName = "claudio";
export const AskToolName = "mcp__claudio__ask";

const Option = z.object({
  label: z.string().describe("The display text for this option. Concise, one to five words."),
  description: z.string().describe("What this option means, or what happens if it is chosen. Say what it costs."),
  preview: z.string().optional().describe("Optional longer detail shown when this option is picked, such as the exact wording or shape it would produce."),
});

const Question = z.object({
  question: z.string().describe("The complete question, ending in a question mark."),
  header: z.string().describe("A very short label shown as a chip above the question, at most twelve characters."),
  multiSelect: z.boolean().describe("True when more than one option may be chosen at once."),
  options: z.array(Option).min(2).max(4).describe("Two to four choices. Do not add your own Other option, one is always offered."),
});

const Description = [
  "Ask the user to decide something only they can decide, and wait for their answer.",
  "Use it when the request is ambiguous in a way that changes what you build, when a choice is a matter of their preference rather than of correctness, or when you are about to make an assumption you would rather have confirmed.",
  "Do not use it for anything you can settle by reading the place, and do not use it to ask permission to continue.",
  "Ask up to four questions at once rather than stopping four separate times.",
  "If you would recommend one option, put it first and end its label with (Recommended).",
  "An Other choice with a free text box is added to every question automatically, so never write one yourself.",
].join(" ");

function Describe(Questions, Answers) {
  const Parts = Questions.map((Entry) => {
    const Given = Answers[Entry.question];

    if (Given === undefined || Given === "") {
      return `"${Entry.question}"="[The user skipped this one, so decide it yourself and say what you picked]"`;
    }

    return `"${Entry.question}"="${Given}"`;
  });

  return [
    `The user answered: ${Parts.join(", ")}.`,
    "Read the answers carefully. They may ask for something different, correct a premise, or tell you not to proceed, and what they actually say wins over what you expected.",
  ].join(" ");
}

export function ReadReport(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  const Parts = [(Found.tree || []).join("\n")];

  for (const Entry of Found.sources || []) {
    Parts.push(`--- ${Entry.path}\n${Entry.source}`);
  }

  if (Found.truncated) {
    Parts.push("Stopped at 400 instances. Narrow the path or lower the depth to see the rest.");
  }

  return Parts.join("\n");
}

export function PropertyReport(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  const Parts = [`${Found.path} [${Found.className}]`, ...(Found.values || [])];

  if (Found.unreadable && Found.unreadable.length > 0) {
    Parts.push(`Could not read: ${Found.unreadable.join(", ")}`);
  }

  return Parts.join("\n");
}

export function ApiReport(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  if (Found.classes) {
    return Found.classes.join(" ");
  }

  if (Found.items) {
    return `${Found.enumName}\n${Found.items.join("\n")}`;
  }

  if (Found.hits) {
    return Found.hits.length > 0 ? Found.hits.join("\n") : `Nothing matches "${Found.search}".`;
  }

  const Parts = [];
  const Head = [Found.className];

  if (Found.inherits && Found.inherits.length > 0) {
    Head.push(`inherits ${Found.inherits.join(" < ")}`);
  }

  if (!Found.creatable) {
    Head.push("not creatable");
  }

  Parts.push(Head.join(", "));

  if (Found.member && Found.properties.length === 0 && Found.methods.length === 0 && Found.events.length === 0) {
    return `${Found.className} has no member called "${Found.member}".`;
  }

  for (const [Label, Lines] of [["properties", Found.properties], ["methods", Found.methods], ["events", Found.events]]) {
    if (Lines && Lines.length > 0) {
      Parts.push(`${Label}:`);
      Parts.push(Lines.map((Line) => `  ${Line}`).join("\n"));
    }
  }

  if (Found.subclasses && Found.subclasses.length > 0 && !Found.member) {
    Parts.push(`subclasses: ${Found.subclasses.join(" ")}`);
  }

  return Parts.join("\n");
}

export function ExecuteReport(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  const Parts = [];

  if (Found.error) {
    Parts.push(Found.error);

    if (Found.line) {
      Parts.push(Found.line);
    }

    if (Found.trace) {
      Parts.push(Found.trace);
    }
  } else if (Found.result !== undefined) {
    Parts.push(Found.result);
  }

  if (Found.output && Found.output.length > 0) {
    Parts.push(Found.output.join("\n"));
  }

  if (Parts.length === 0) {
    return Found.undo ? "Ran. Nothing returned or printed; undo will reverse it." : "Ran. Nothing returned or printed.";
  }

  return Parts.join("\n");
}

export function LintReport(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  const Scripts = Found.scripts || [];
  const Lines = Scripts.map((Entry) => [Entry.path].concat((Entry.lines || []).map((Warning) => `  ${Warning}`)).join("\n"));

  if (Found.skipped && Found.skipped.length > 0) {
    Lines.push(`Could not check: ${Found.skipped.join(", ")}`);
  }

  return Lines.length > 0 ? Lines.join("\n") : "No warnings.";
}

const ExecuteDescription = [
  "Run Luau inside the open place and get back what it returned, what it printed, and where it failed.",
  "Changes are recorded as one undo step, so the user can reverse them; pass readOnly when you only want to look, and nothing is recorded.",
  "Anything the script prints or warns comes back with the result, so print what you want to see rather than returning one value at a time.",
  "Call _G.ClaudioFresh(module) to require a module past its cache when you have just rewritten it.",
].join(" ");

const PressDescription = [
  "Press a button in the running experience by naming it, rather than by guessing screen coordinates.",
  "Give the full instance path, such as Players.Someone.PlayerGui.Menu.Play, and it works out where that lands on screen itself.",
  "This needs a play session with a character, so it cannot reach a plugin window or anything in edit mode, and the engine refuses presses that land on Roblox's own interface.",
  "A press that reaches nothing still reports as sent, so check the place afterwards rather than trusting the reply.",
].join(" ");

const PlaytestDescription = [
  "Start, stop, inspect or add players to a playtest of the open place, so behaviour that only happens at runtime can be checked.",
  "Always stop what you started: a place left running keeps executing scripts, holds the editor in a running state, and every later edit lands in a data model that is about to be thrown away.",
  "Check status first rather than assuming, and read the reply, because starting something already running and stopping something already stopped are both mistakes worth knowing about.",
  "play mode gives a real character and PlayerGui, run mode simulates without one, and multiplayer starts a server with several clients.",
  "Stopping and adding players can only be done from inside the running session, so those need the place to allow HTTP requests before the playtest starts.",
].join(" ");

const LintDescription = [
  "Check scripts in the open place for analyzer warnings, including scripts nobody has edited.",
  "Use it to survey a place you have just been given, before changing anything, so pre-existing problems are reported rather than silently attributed to your own edits.",
  "Scripts you edit are already checked automatically after the edit, so do not call this straight after editing.",
  "Pass paths to narrow it to part of the tree, or leave it empty to check everything.",
].join(" ");



export function AskServerFor(Pose, Reach, ReachIn) {
  return createSdkMcpServer({
    name: AskServerName,
    version: "1.0.0",
    tools: [
      tool("instances", "Say whether Studio is open and whether the Claudio plugin has checked in. Ask this before assuming nothing is connected, and never open Studio yourself on the strength of an empty answer.", {}, async () => {
        const { Describe } = await import("./StudioPresence.js");
        const { Presence } = await import("./Studio.js");
        const { StudioProcesses } = await import("./StudioPresence.js");

        return { content: [{ type: "text", text: Describe({ ...Presence(), processes: await StudioProcesses() }) }] };
      }),
      tool("read", "Read a part of the open place in one call: the instance tree under a path, plus the source of scripts in it. Prefer this over walking the tree with separate calls.", {
        path: z.string().optional().describe("Where to start, such as ServerScriptService. Defaults to the whole place."),
        depth: z.number().optional().describe("How many levels deep, 3 by default."),
        contains: z.string().optional().describe("Only return script sources containing this text."),
      }, async (Input) => {
        const Found = await Reach("read", { path: Input.path || "game", depth: Input.depth, contains: Input.contains });

        return { content: [{ type: "text", text: ReadReport(Found) }] };
      }),
      tool("properties", "Read an instance's properties, listing every property its class actually has and naming any that could not be read, so a missing one is never mistaken for an unset one.", {
        path: z.string().describe("Full instance path."),
        names: z.array(z.string()).optional().describe("Only these properties. Omit for all of them."),
      }, async (Input) => {
        return { content: [{ type: "text", text: PropertyReport(await Reach("properties", { path: Input.path, names: Input.names })) }] };
      }),
      tool("api", "Ask the running engine about the Roblox API: a class's properties, methods and events with full signatures, parameter names, return types, what it inherits and what inherits from it, which members are deprecated or read only, and what security each needs. This is the version of Roblox actually installed, so prefer it over remembering an API or reading documentation that may describe a different version. Narrow with member for one member, search to find a class, enum or member by name, or enumName for an enum's items.", {
        className: z.string().optional().describe("Class to describe, such as Lighting. Leave out to list every class."),
        member: z.string().optional().describe("Only this member of the class."),
        search: z.string().optional().describe("Find a class or enum whose name contains this. Pass className too to search that class's members."),
        enumName: z.string().optional().describe("An enum to list the items of, such as Material."),
      }, async (Input) => {
        const Found = await Reach("api", { className: Input.className, member: Input.member, search: Input.search, enumName: Input.enumName });

        return { content: [{ type: "text", text: ApiReport(Found) }] };
      }),
      tool("modify", "Change the place with one undo step: set properties, create, delete, rename or reparent. Prefer this over writing a script for a change this can express, because the arguments are checked and the change is reversible.", {
        action: z.enum(["set", "create", "delete", "rename", "reparent"]),
        path: z.string().optional().describe("The instance to act on."),
        parent: z.string().optional().describe("Parent path, for create and reparent."),
        className: z.string().optional().describe("Class to create."),
        name: z.string().optional().describe("Name to give it, for create and rename."),
        properties: z.record(z.any()).optional().describe("Property names and values, for set and create."),
        label: z.string().optional().describe("What the undo step should be called."),
      }, async (Input) => {
        const Found = await Reach("modify", Input);

        return { content: [{ type: "text", text: Found && Found.error ? Found.error : (Found && Found.text) || "Studio did not say what happened." }] };
      }),
      tool("capture", "Take a picture of the Studio viewport. Give around with an instance path to crop tightly to that thing, which works for a part, a model or any on screen GuiObject, and costs a fraction of a whole viewport to look at. Give path to point the camera at something first, or x, y, width and height to crop by hand. The camera is always put back where it was. Plugin windows are not in the viewport, so they cannot be captured this way.", {
        around: z.string().optional().describe("Instance to crop tightly around, such as Workspace.Model or a GuiObject path."),
        padding: z.number().optional().describe("Pixels of margin around it, 8 by default."),
        path: z.string().optional().describe("Instance to frame the camera on before shooting."),
        x: z.number().optional().describe("Left edge of the region, in pixels from the left of the Studio window."),
        y: z.number().optional().describe("Top edge of the region."),
        width: z.number().optional().describe("Region width. Give width and height together to crop."),
        height: z.number().optional().describe("Region height."),
      }, async (Input) => {
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
      }),
      tool("execute", ExecuteDescription, {
        code: z.string().describe("The Luau to run. Return a value to get it back."),
        target: z.enum(["edit", "server", "client"]).optional().describe("Where to run it. edit is the editor itself and the default; server and client are the running play session and need one to be open."),
        readOnly: z.boolean().optional().describe("Set when the script only reads, so no undo step is recorded. Only meaningful in edit."),
        label: z.string().optional().describe("What the undo step should be called, such as \"Rename the doors\"."),
      }, async (Input) => {
        const Where = Input.target || "edit";

        if (Where !== "edit") {
          const { RuntimeLive } = await import("./Studio.js");

          if (!RuntimeLive()) {
            return { content: [{ type: "text", text: "No play session is reachable. Start one with the playtest tool, or from the toolbar, and give it a moment to connect." }] };
          }
        }

        const Found = await ReachIn(Where === "edit" ? "edit" : "server", "execute", { code: Input.code, target: Where, readOnly: Input.readOnly === true, label: Input.label });

        return { content: [{ type: "text", text: ExecuteReport(Found) }] };
      }),
      tool("press", PressDescription, { path: z.string().describe("Full instance path of the GuiObject to press.") }, async (Input) => {
        const { RuntimeLive } = await import("./Studio.js");

        if (!RuntimeLive()) {
          return { content: [{ type: "text", text: "No play session is reachable, and a press has to happen on the client where the interface lives. Start one with the playtest tool and give it a moment to connect." }] };
        }

        const Found = await ReachIn("server", "press", { path: Input.path });

        return { content: [{ type: "text", text: Found && Found.error ? Found.error : (Found && Found.text) || "Studio did not say what happened." }] };
      }),
      tool("playtest", PlaytestDescription, {
        action: z.enum(["start", "stop", "status", "players"]).describe("What to do. Use status to find out what is happening before changing it."),
        mode: z.enum(["play", "run", "multiplayer"]).optional().describe("How to start it. play gives a character, run simulates without one, multiplayer starts a server with several clients. Defaults to play."),
        players: z.number().optional().describe("How many players, for multiplayer starts and for the players action."),
      }, async (Input) => {
        const Found = await Reach("playtest", { action: Input.action, mode: Input.mode, players: Input.players });

        if (Found && Found.relay) {
          const { RuntimeLive } = await import("./Studio.js");

          if (!RuntimeLive()) {
            return { content: [{ type: "text", text: `Studio only allows ${Found.relay} from inside the running session, and the session is not reachable. It needs Allow HTTP Requests turned on in Game Settings before the playtest starts, otherwise stop it from Studio's toolbar.` }] };
          }

          const Inside = await ReachIn("server", "playtest", { action: Found.relay, players: Found.players });

          return { content: [{ type: "text", text: Inside && Inside.error ? Inside.error : (Inside && Inside.text) || "The session did not say what happened." }] };
        }

        return { content: [{ type: "text", text: Found && Found.error ? Found.error : (Found && Found.text) || "Studio did not say what happened." }] };
      }),
      tool("lint", LintDescription, { paths: z.array(z.string()).optional().describe("Instance paths to check, such as ServerScriptService.Main. Omit to check the whole place.") }, async (Input) => {
        const Found = await Reach("lint", { paths: Input.paths || [] });

        return { content: [{ type: "text", text: LintReport(Found) }] };
      }),
      tool("ask", Description, { questions: z.array(Question).min(1).max(4) }, async (Input) => {
        const Answers = await Pose(Input.questions);

        if (!Answers) {
          return {
            content: [{
              type: "text",
              text: "The user dismissed the question without answering. Stop and wait for their next message rather than guessing.",
            }],
          };
        }

        return { content: [{ type: "text", text: Describe(Input.questions, Answers) }] };
      }),
    ],
  });
}
