import { createSdkMcpServer, tool } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod/v3";
import { StudioTools } from "./Tools.js";

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

export function LogReport(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  const Lines = Found.lines || [];

  if (Lines.length === 0) {
    return `Nothing in the log matched, out of ${Found.scanned} entries.`;
  }

  const Tail = Found.skipped > 0 ? `\n${Found.skipped} older matches not shown; raise limit to see them.` : "";

  return `${Lines.join("\n")}${Tail}`;
}

export function FindReport(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  const Hits = Found.hits || [];

  if (Hits.length === 0) {
    return `No match in ${Found.scanned} scripts.`;
  }

  return `${Hits.join("\n")}${Found.more > 0 ? `\n${Found.more} more matches not shown; raise limit to see them.` : ""}`;
}

export function SourceReport(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  if (Found.lines) {
    return `${Found.path}, ${Found.total} lines\n${Found.lines.join("\n")}`;
  }

  return Found.text || "Done.";
}

export function SelectReport(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  if (Found.paths) {
    return Found.paths.length > 0 ? Found.paths.join("\n") : "Nothing is selected.";
  }

  return Found.text || "Done.";
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

  if (Found.shared > 0) {
    Parts.push(`${Found.shared} members every instance has are not listed; pass inherited to see them.`);
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







export function AskServerFor(Pose, Reach, ReachIn) {
  const Shared = StudioTools({
    Reach,
    ReachIn: (Role, Kind, Input, Timeout) => ReachIn(Role, Kind, Input, Timeout),
    Presence: async () => {
      const { Describe: Say } = await import("./StudioPresence.js");
      const { Presence } = await import("./Studio.js");
      const { StudioProcesses } = await import("./StudioPresence.js");

      return Say({ ...Presence(), processes: await StudioProcesses() });
    },
    RuntimeLive: async () => {
      const { RuntimeLive } = await import("./Studio.js");

      return RuntimeLive();
    },
  });

  return createSdkMcpServer({
    name: AskServerName,
    version: "1.0.0",
    tools: [
      ...Shared.map((Entry) => tool(Entry.Name, Entry.Description, Entry.Schema, Entry.Run)),
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