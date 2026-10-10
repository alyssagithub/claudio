import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { SessionsRoot } from "./Config.js";

const CacheFile = path.join(os.homedir(), ".claudio", "stats.json");
const ImageData = /"data":"[A-Za-z0-9+\/=]{256,}"/g;

type Day = {
  t: number;
  n: number;
  m: Record<string, [number, number]>;
};

type FileTotals = {
  size: number;
  read: number;
  top: boolean;
  days: Record<string, Day>;
  start?: [string, number];
};

type Cache = {
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
    return JSON.parse(fs.readFileSync(CacheFile, "utf8")) as Cache;
  } catch {
    return {files: {}};
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
  const Tokens = (Usage.input_tokens || 0) + (Usage.output_tokens || 0) + (Usage.cache_creation_input_tokens || 0) + (Usage.cache_read_input_tokens || 0);
  const Model = Line.type === "assistant" && Line.message && Line.message.model && Line.message.model !== "<synthetic>" ? Line.message.model : null;

  Today.n += Totals.top ? 1 : 0;
  Today.t += Tokens;
  Totals.start = Totals.start || [Key, When.getHours()];

  if (Model) {
    const Held = Today.m[Model] || (Today.m[Model] = [0, 0]);

    Held[0] += Tokens;
    Held[1] += 1;
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
  const Hours: Record<string, number> = {};
  const Models: Record<string, {tokens: number; messages: number}> = {};
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

      for (const [Model, [Used, Sent]] of Object.entries(Day.m)) {
        const Name = ModelName(Model);
        const Held = Models[Name] || (Models[Name] = {tokens: 0, messages: 0});

        Held.tokens += Used;
        Held.messages += Sent;
      }
    }

    if (Counted && Totals.top) {
      Sessions += 1;
    }

    if (Totals.top && Totals.start && Totals.start[0] >= Cutoff) {
      Hours[String(Totals.start[1])] = (Hours[String(Totals.start[1])] || 0) + 1;
    }
  }

  const Ranked = Object.entries(Models).map(([Name, Held]) => ({name: Name, ...Held})).sort((Left, Right) => Right.tokens - Left.tokens);
  const Peak = Object.entries(Hours).sort((Left, Right) => Right[1] - Left[1])[0];
  const Grid: number[] = [];

  for (let Back = 181; Back >= 0; Back -= 1) {
    Grid.push(PerDay[LocalDay(new Date(Today.getFullYear(), Today.getMonth(), Today.getDate() - Back))] || 0);
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
    firstDay: LocalDay(new Date(Today.getFullYear(), Today.getMonth(), Today.getDate() - 181)),
  };
}
