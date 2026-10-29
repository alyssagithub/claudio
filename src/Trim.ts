import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import readline from "node:readline";

const DoneFile = path.join(os.homedir(), ".claudio", "trimmed.json");

const PictureNote = "[An earlier picture was left out when this chat was resumed, to save context. Capture again if you need to see it; the line below says where it was saved.]";

async function* Lines(File: string, Start: number): AsyncGenerator<string> {
  const Reader = readline.createInterface({input: fs.createReadStream(File, {encoding: "utf8", start: Start}), crlfDelay: Infinity});

  try {
    for await (const Line of Reader) {
      yield Line;
    }
  } finally {
    Reader.close();
  }
}

function IsPrompt(Entry: { type?: string; isSidechain?: boolean; message?: { content?: unknown } }): boolean {
  if (Entry.type !== "user" || Entry.isSidechain) {
    return false;
  }

  const Content = Entry.message && Entry.message.content;

  return typeof Content === "string" || (Array.isArray(Content) && !Content.some((Block) => Block && Block.type === "tool_result"));
}

export async function TrimOldResults(File: string, KeepPrompts = 3): Promise<{ Pictures: number; Logs: number }> {
  const Done = (() => {
    try {
      return JSON.parse(fs.readFileSync(DoneFile, "utf8")) as Record<string, number>;
    } catch {
      return {} as Record<string, number>;
    }
  })();
  const Start = Done[File] && Done[File] <= fs.statSync(File).size ? Done[File] : 0;
  const Prompts: { Line: number; Byte: number }[] = [];
  const LogCalls = new Set<string>();
  let Count = 0;
  let Byte = Start;

  for await (const Line of Lines(File, Start)) {
    if (Line.includes('"type":"user"') && !Line.includes('"tool_result"')) {
      try {
        if (IsPrompt(JSON.parse(Line))) {
          Prompts.push({Line: Count, Byte});
        }
      } catch {}
    }

    for (const Found of Line.matchAll(/"id":"(toolu_[A-Za-z0-9]+)","name":"mcp__claudio__logs"/g)) {
      LogCalls.add(Found[1]);
    }

    Count += 1;
    Byte += Buffer.byteLength(Line, "utf8") + 1;
  }

  const Cutoff = Prompts.length > KeepPrompts ? Prompts[Prompts.length - KeepPrompts].Line : -1;
  const Reached = Prompts.length > KeepPrompts ? Prompts[Prompts.length - KeepPrompts].Byte : Start;
  const Totals = {Pictures: 0, Logs: 0};

  if (Cutoff < 0) {
    return Totals;
  }

  const Temporary = `${File}.trimming`;
  const Out = fs.createWriteStream(Temporary, {encoding: "utf8"});
  let Index = 0;
  let Saved = 0;

  if (Start > 0) {
    await new Promise<void>((Resolve, Reject) => {
      const Head = fs.createReadStream(File, {end: Start - 1});

      Head.on("error", Reject).on("end", () => Resolve()).pipe(Out, {end: false});
    });
  }

  for await (const Line of Lines(File, Start)) {
    let Written = Line;

    if (Index < Cutoff && Line.includes('"tool_result"') && (Line.includes('"type":"image"') || [...LogCalls].some((Id) => Line.includes(Id)))) {
      try {
        const Entry = JSON.parse(Line);
        let Touched = false;

        for (const Block of (Entry.message && Array.isArray(Entry.message.content)) ? Entry.message.content : []) {
          if (!Block || Block.type !== "tool_result" || !Array.isArray(Block.content)) {
            continue;
          }

          Block.content = Block.content.map((Part: { type?: string; text?: string }) => {
            if (Part && Part.type === "image") {
              Totals.Pictures += 1;
              Touched = true;

              return {type: "text", text: PictureNote};
            }

            if (Part && Part.type === "text" && LogCalls.has(Block.tool_use_id) && typeof Part.text === "string" && Part.text.length > 3000) {
              Totals.Logs += 1;
              Touched = true;

              return {type: "text", text: `${Part.text.slice(0, 1500)}\n\n[The rest of this old log, ${Part.text.length - 1500} characters, was left out when this chat was resumed, to save context. Read the logs again if you need it.]`};
            }

            return Part;
          });
        }

        if (Touched) {
          Written = JSON.stringify(Entry);
          Saved += Buffer.byteLength(Line, "utf8") - Buffer.byteLength(Written, "utf8");
        }
      } catch {}
    }

    if (!Out.write(`${Written}\n`)) {
      await new Promise((Resolve) => Out.once("drain", Resolve));
    }

    Index += 1;
  }

  await new Promise<void>((Resolve, Reject) => Out.end((Trouble?: Error | null) => Trouble ? Reject(Trouble) : Resolve()));

  const Changed = Totals.Pictures + Totals.Logs > 0 && fs.statSync(Temporary).size > 0;

  if (Changed) {
    fs.renameSync(Temporary, File);
  } else {
    fs.rmSync(Temporary, {force: true});
  }

  Done[File] = Changed ? Reached - Saved : Reached;
  fs.writeFileSync(DoneFile, JSON.stringify(Done));

  return Totals;
}

export type ToolShape = { description: string; properties: Record<string, string> };

export async function UnpinChangedTools(File: string, Current: Map<string, ToolShape>): Promise<number> {
  const Lines = (await fs.promises.readFile(File, "utf8")).split("\n");
  let Dropped = 0;

  const Kept = Lines.map((Line) => {
    if (!Line.includes("\"deferred_tools_record\"") || !Line.includes("\"mcp__claudio__")) {
      return Line;
    }

    let Entry: { attachment?: { entries?: { name?: string; description?: string; input_schema?: { properties?: Record<string, { description?: string }> } }[] } };

    try {
      Entry = JSON.parse(Line);
    } catch {
      return Line;
    }

    const Entries = Entry.attachment && Entry.attachment.entries;

    if (!Entries) {
      return Line;
    }

    const Fresh = Entries.filter((Pinned) => {
      const Now = Pinned.name ? Current.get(Pinned.name) : undefined;

      if (!Now) {
        return true;
      }

      const Properties = (Pinned.input_schema && Pinned.input_schema.properties) || {};
      const Same = Pinned.description === Now.description
        && Object.keys(Properties).length === Object.keys(Now.properties).length
        && Object.entries(Now.properties).every(([Name, Said]) => Properties[Name] !== undefined && (Properties[Name].description || "") === Said);

      return Same;
    });

    if (Fresh.length === Entries.length) {
      return Line;
    }

    Dropped += Entries.length - Fresh.length;
    Entry.attachment!.entries = Fresh;

    return JSON.stringify(Entry);
  });

  if (Dropped > 0) {
    await fs.promises.writeFile(`${File}.claudio-writing`, Kept.join("\n"));
    await fs.promises.rename(`${File}.claudio-writing`, File);
  }

  return Dropped;
}
