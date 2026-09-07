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

// The answer text is what the model sees, so it has to carry which question
// each answer belongs to; the plugin renders from the question itself.
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

export function AskServerFor(Pose) {
  return createSdkMcpServer({
    name: AskServerName,
    version: "1.0.0",
    tools: [
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
