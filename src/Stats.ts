import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { SessionsRoot } from "./Config.js";

const CacheFile = path.join(os.homedir(), ".claudio", "stats.json");
const ImageData = /"data":"[A-Za-z0-9+\/=]{256,}"/g;

type Day = {
  t: number;
  n: number;
  m: Record<string, [number, number, number]>;
};

type FileTotals = {
  size: number;
  read: number;
  top: boolean;
  days: Record<string, Day>;
  start?: [string, number];
};

type Cache = {
  version?: number;
  files: Record<string, FileTotals>;
};

function ListFiles(Folder: string, Depth = 0): string[] {
  let Entries: fs.Dirent[];

  try {
    Entries = fs.readdirSync(Folder, {withFileTypes: true});
  } catch {
    return [];
  }

  return Entries.flatMap((Entry) => {
    const Full = path.join(Folder, Entry.name);

    if (Entry.isDirectory()) {
      return ListFiles(Full, Depth + 1);
    }

    return Entry.name.endsWith(".jsonl") ? [Full] : [];
  });
}

function ReadCache(): Cache {
  try {
    const Held = JSON.parse(fs.readFileSync(CacheFile, "utf8")) as Cache;

    return Held.version === 2 ? Held : {version: 2, files: {}};
  } catch {
    return {version: 2, files: {}};
  }
}

function LocalDay(When: Date): string {
  return `${When.getFullYear()}-${String(When.getMonth() + 1).padStart(2, "0")}-${String(When.getDate()).padStart(2, "0")}`;
}

function Count(Totals: FileTotals, Raw: string) {
  if (!Raw.includes("\"type\":\"assistant\"") && !Raw.includes("\"type\":\"user\"")) {
    return;
  }

  let Line: {type?: string; timestamp?: string; isMeta?: boolean; message?: {id?: string; model?: string; usage?: Record<string, number>}};

  try {
    Line = JSON.parse(Raw.length > 4096 ? Raw.replace(ImageData, "\"data\":\"\"") : Raw);
  } catch {
    return;
  }

  if ((Line.type !== "assistant" && Line.type !== "user") || Line.isMeta || !Line.timestamp) {
    return;
  }

  const When = new Date(Line.timestamp);

  if (Number.isNaN(When.getTime())) {
    return;
  }

  const Key = LocalDay(When);
  const Today = Totals.days[Key] || (Totals.days[Key] = {t: 0, n: 0, m: {}});
  const Usage = (Line.message && Line.message.usage) || {};
  const Input = Usage.input_tokens || 0;
  const Output = Usage.output_tokens || 0;
  const Model = Line.type === "assistant" && Line.message && Line.message.model && Line.message.model !== "<synthetic>" ? Line.message.model : null;

  Today.n += Totals.top ? 1 : 0;
  Today.t += Input + Output;
  Totals.start = Totals.start || [Key, When.getHours()];

  if (Model) {
    const Held = Today.m[Model] || (Today.m[Model] = [0, 0, 0]);

    Held[0] += Input;
    Held[1] += Output;
    Held[2] += 1;
  }
}

export function RefreshStats() {
  const Cache = ReadCache();
  const Seen = new Set<string>();
  const Chunk = Buffer.alloc(8 * 1024 * 1024);

  for (const File of ListFiles(SessionsRoot)) {
    let Size: number;

    try {
      Size = fs.statSync(File).size;
    } catch {
      continue;
    }

    Seen.add(File);

    let Totals = Cache.files[File];

    if (!Totals || Size < Totals.read) {
      Totals = Cache.files[File] = {size: 0, read: 0, top: path.dirname(path.dirname(File)) === SessionsRoot, days: {}};
    }

    if (Size === Totals.read) {
      continue;
    }

    const Descriptor = fs.openSync(File, "r");
    let Offset = Totals.read;
    let Carried = Buffer.alloc(0);

    try {
      while (Offset < Size) {
        const Got = fs.readSync(Descriptor, Chunk, 0, Math.min(Chunk.length, Size - Offset), Offset);

        if (Got <= 0) {
          break;
        }

        Offset += Got;

        const Joined = Buffer.concat([Carried, Chunk.subarray(0, Got)]);
        const Ended = Joined.lastIndexOf(10);

        if (Ended < 0) {
          Carried = Joined;
          continue;
        }

        for (const Raw of Joined.subarray(0, Ended).toString("utf8").split("\n")) {
          Count(Totals, Raw);
        }

        Carried = Joined.subarray(Ended + 1);
      }
    } finally {
      fs.closeSync(Descriptor);
    }

    Totals.read = Offset - Carried.length;
    Totals.size = Size;
  }

  for (const File of Object.keys(Cache.files)) {
    if (!Seen.has(File)) {
      delete Cache.files[File];
    }
  }

  fs.mkdirSync(path.dirname(CacheFile), {recursive: true});
  fs.writeFileSync(`${CacheFile}.writing`, JSON.stringify(Cache));
  fs.renameSync(`${CacheFile}.writing`, CacheFile);
}

function ModelName(Id: string): string {
  const Parts = Id.replace(/^claude-/, "").replace(/-\d{8}$/, "").replace(/\[.*\]$/, "").split("-");
  const Family = Parts.find((Part) => /^[a-z]+$/i.test(Part)) || Parts[0];
  const Numbers = Parts.filter((Part) => /^\d+$/.test(Part));

  return `${Family.charAt(0).toUpperCase()}${Family.slice(1)}${Numbers.length > 0 ? ` ${Numbers.join(".")}` : ""}`;
}

export function StatsAge(): number {
  try {
    return Date.now() - fs.statSync(CacheFile).mtimeMs;
  } catch {
    return Infinity;
  }
}

export function StatsFor(Range: string) {
  const Cache = ReadCache();
  const Days = Range === "7" ? 7 : Range === "30" ? 30 : 0;
  const Today = new Date();
  const Cutoff = Days > 0 ? LocalDay(new Date(Today.getFullYear(), Today.getMonth(), Today.getDate() - Days + 1)) : "";
  const PerDay: Record<string, number> = {};
  const Sent: Record<string, number> = {};
  const Chart: Record<string, Record<string, number>> = {};
  const Hours: Record<string, number> = {};
  const Models: Record<string, {input: number; output: number; messages: number}> = {};
  let Sessions = 0;
  let Messages = 0;
  let Tokens = 0;

  for (const Totals of Object.values(Cache.files)) {
    let Counted = false;

    for (const [Key, Day] of Object.entries(Totals.days)) {
      if (Key < Cutoff) {
        continue;
      }

      Counted = true;
      Messages += Day.n;
      Tokens += Day.t;
      PerDay[Key] = (PerDay[Key] || 0) + Day.t;
      Sent[Key] = (Sent[Key] || 0) + Day.n;

      for (const [Model, [Input, Output, Replies]] of Object.entries(Day.m)) {
        const Name = ModelName(Model);
        const Held = Models[Name] || (Models[Name] = {input: 0, output: 0, messages: 0});
        const Spent = Chart[Key] || (Chart[Key] = {});

        Held.input += Input;
        Held.output += Output;
        Held.messages += Replies;
        Spent[Name] = (Spent[Name] || 0) + Input + Output;
      }
    }

    if (Counted && Totals.top) {
      Sessions += 1;
    }

    if (Totals.top && Totals.start && Totals.start[0] >= Cutoff) {
      Hours[String(Totals.start[1])] = (Hours[String(Totals.start[1])] || 0) + 1;
    }
  }

  const Ranked = Object.entries(Models).map(([Name, Held]) => ({name: Name, tokens: Held.input + Held.output, ...Held})).filter((Model) => Model.tokens > 0).sort((Left, Right) => Right.tokens - Left.tokens);
  const Peak = Object.entries(Hours).sort((Left, Right) => Right[1] - Left[1])[0];
  const Grid: number[] = [];
  const GridMessages: number[] = [];
  const First = Days > 0 ? Cutoff : (Object.keys(Chart).sort()[0] || LocalDay(Today));
  const Bars: {date: string; models: Record<string, number>}[] = [];

  for (let Back = 181; Back >= 0; Back -= 1) {
    const Key = LocalDay(new Date(Today.getFullYear(), Today.getMonth(), Today.getDate() - Back));

    Grid.push(PerDay[Key] || 0);
    GridMessages.push(Sent[Key] || 0);
  }

  for (let Step = new Date(`${First}T12:00:00`); LocalDay(Step) <= LocalDay(Today); Step = new Date(Step.getFullYear(), Step.getMonth(), Step.getDate() + 1, 12)) {
    Bars.push({date: LocalDay(Step), models: Chart[LocalDay(Step)] || {}});
  }

  return {
    sessions: Sessions,
    messages: Messages,
    tokens: Tokens,
    activeDays: Object.keys(PerDay).length,
    peakHour: Peak ? Number(Peak[0]) : null,
    favoriteModel: Ranked[0] ? Ranked[0].name : null,
    models: Ranked,
    grid: Grid,
    gridMessages: GridMessages,
    gridEnd: LocalDay(Today),
    bars: Bars,
  };
}
