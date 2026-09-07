import { CappedTools, ResultCapCharacters } from "./Config.js";

const CapThreshold = ResultCapCharacters + 1000;

function TextOf(Block) {
  return Block && typeof Block.text === "string" ? Block.text : "";
}

function CapText(Name, Text) {
  const Structured = /^\s*[{[]/.test(Text);
  const Head = Structured ? ResultCapCharacters : Math.floor(ResultCapCharacters * 0.75);
  const Shape = Structured
    ? "from the end, so it is no longer parseable as structured data"
    : "from the middle, so the text after the cut is the tail of the output";
  const Note = `

[Claudio truncated this result. ${Text.length} characters of text came back and ${Text.length - ResultCapCharacters} were removed ${Shape}. What you have above is real and usable, so answer from it if it already covers the question. Never call ${Name} again with the same arguments, and only call it again at all if you specifically need a part that was cut, naming a narrower target such as one subtree, one line range, or a tighter filter.]`;

  if (Structured) {
    return Text.slice(0, Head) + Note;
  }

  return Text.slice(0, Head) + Note + "\n\n" + Text.slice(Text.length - (ResultCapCharacters - Head));
}

export function CapToolOutput(Name, Response) {
  if (ResultCapCharacters <= 0 || typeof Name !== "string" || !(Name.startsWith("mcp__") || CappedTools.includes(Name))) {
    return null;
  }

  if (typeof Response === "string") {
    return Response.length > CapThreshold ? CapText(Name, Response) : null;
  }

  if (!Response || typeof Response !== "object" || Response.structuredContent) {
    return null;
  }

  const Blocks = Array.isArray(Response) ? Response : Response.content;

  if (!Array.isArray(Blocks)) {
    return null;
  }

  const Joined = Blocks.map(TextOf).join("\n");

  if (Joined.length <= CapThreshold) {
    return null;
  }

  const Content = [];
  let Placed = false;

  for (const Block of Blocks) {
    if (TextOf(Block).length === 0) {
      Content.push(Block);
      continue;
    }

    if (Placed) {
      continue;
    }

    Placed = true;
    Content.push({ ...Block, text: CapText(Name, Joined) });
  }

  return Array.isArray(Response) ? Content : { ...Response, content: Content };
}
