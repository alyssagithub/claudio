import fs from "node:fs";
import type { LineCount } from "./Types.js";

const EditingTools = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"]);

export function CountLines(Before: string, After: string): LineCount {
  const Old = Before === "" ? [] : Before.split(/\r?\n/);
  const New = After === "" ? [] : After.split(/\r?\n/);

  let Start = 0;

  while (Start < Old.length && Start < New.length && Old[Start] === New[Start]) {
    Start += 1;
  }

  let OldEnd = Old.length;
  let NewEnd = New.length;

  while (OldEnd > Start && NewEnd > Start && Old[OldEnd - 1] === New[NewEnd - 1]) {
    OldEnd -= 1;
    NewEnd -= 1;
  }

  const Removed = OldEnd - Start;
  const Added = NewEnd - Start;

  if (Removed === 0 || Added === 0 || Removed * Added > 4000000) {
    return { added: Added, removed: Removed };
  }

  let Row = new Array(Added + 1).fill(0);

  for (let Left = Start; Left < OldEnd; Left += 1) {
    const Next = new Array(Added + 1).fill(0);

    for (let Right = Start; Right < NewEnd; Right += 1) {
      const At = Right - Start + 1;

      Next[At] = Old[Left] === New[Right] ? Row[At - 1] + 1 : Math.max(Row[At], Next[At - 1]);
    }

    Row = Next;
  }

  const Common = Row[Added];

  return { added: Added - Common, removed: Removed - Common };
}

export function EditedFile(ToolName: string, Input: unknown): string | null {
  const Named = Input as {file_path?: unknown};

  if (!EditingTools.has(ToolName) || !Named || typeof Named.file_path !== "string") {
    return null;
  }

  return Named.file_path;
}

export function ReadFileText(File: string): string {
  try {
    return fs.readFileSync(File, "utf8");
  } catch {
    return "";
  }
}