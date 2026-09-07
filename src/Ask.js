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

const PlaytestDescription = [
  "Start, stop or inspect a simulation of the open place, so behaviour that only happens at runtime can be checked.",
  "Always stop what you started: a place left running keeps executing scripts, holds the editor in a running state, and every later edit lands in a data model that is about to be thrown away.",
  "Check status first rather than assuming, and read the reply, because starting something already running and stopping something already stopped are both mistakes worth knowing about.",
  "This runs the place without a player character, so server scripts, physics and module behaviour can be exercised but anything reading LocalPlayer or PlayerGui cannot.",
].join(" ");

const LintDescription = [
  "Check scripts in the open place for analyzer warnings, including scripts nobody has edited.",
  "Use it to survey a place you have just been given, before changing anything, so pre-existing problems are reported rather than silently attributed to your own edits.",
  "Scripts you edit are already checked automatically after the edit, so do not call this straight after editing.",
  "Pass paths to narrow it to part of the tree, or leave it empty to check everything.",
].join(" ");

function Report(Found) {
  if (Found.error) {
    return Found.error;
  }

  const Scripts = Found.scripts || [];

  if (Scripts.length === 0) {
    return `Checked ${Found.checked === 1 ? "1 script" : `${Found.checked || 0} scripts`} and found no warnings.`;
  }

  const Lines = Scripts.map((Entry) => [Entry.path].concat((Entry.lines || []).map((Warning) => `  ${Warning}`)).join("\n"));
  const Counted = Found.checked === 1 ? "1 script" : `${Found.checked || 0} scripts`;

  return [
    `Checked ${Counted}. ${Scripts.length === 1 ? "One carries" : `${Scripts.length} carry`} warnings, none introduced in this session:`,
    Lines.join("\n"),
    "Report these to the user rather than fixing them unasked, because they were already there and fixing them is a separate decision.",
  ].join("\n");
}

export function AskServerFor(Pose, Reach) {
  return createSdkMcpServer({
    name: AskServerName,
    version: "1.0.0",
    tools: [
      tool("playtest", PlaytestDescription, { action: z.enum(["start", "stop", "pause", "status"]).describe("What to do. Use status to find out what is happening before changing it.") }, async (Input) => {
        const Found = await Reach("playtest", { action: Input.action });

        return { content: [{ type: "text", text: Found && Found.error ? Found.error : (Found && Found.text) || "Studio did not say what happened." }] };
      }),
      tool("lint", LintDescription, { paths: z.array(z.string()).optional().describe("Instance paths to check, such as ServerScriptService.Main. Omit to check the whole place.") }, async (Input) => {
        const Found = await Reach("lint", { paths: Input.paths || [] });

        return { content: [{ type: "text", text: Report(Found || {}) }] };
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
