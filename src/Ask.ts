import { createSdkMcpServer, tool } from "@anthropic-ai/claude-agent-sdk";
import { StudioTools } from "./Tools.js";
import type { Reacher, ReacherIn } from "./Tools.js";

export const AskServerName = "claudio";

export type ReadAnswer = { error?: string; tree?: string[]; sources?: { path: string; source: string }[]; truncated?: boolean } | null;

export function ReadReport(Found: ReadAnswer) {
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

export type PropertyAnswer = { error?: string; path?: string; className?: string; values?: string[]; unreadable?: string[] } | null;

export function PropertyReport(Found: PropertyAnswer) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  const Parts = [`${Found.path} [${Found.className}]`, ...(Found.values || [])];

  if (Found.unreadable && Found.unreadable.length > 0) {
    Parts.push(`Could not read: ${Found.unreadable.join(", ")}. Roblox hides these from plugins and scripts; the hidden tool can read them, including Workspace's streaming settings.`);
  }

  return Parts.join("\n");
}

export type LogAnswer = { error?: string; lines?: string[]; scanned?: number; skipped: number } | null;

export function LogReport(Found: LogAnswer) {
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

export type FindAnswer = { error?: string; hits?: string[]; scanned?: number; more: number; searched?: string[]; empty?: number; root?: string } | null;

export function FindReport(Found: FindAnswer) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  const Hits = Found.hits || [];

  if (Hits.length === 0) {
    const Scanned = Found.scanned || 0;
    const Where = Found.searched && Found.searched.length > 0 ? `: ${Found.searched.join(", ")}${Scanned > Found.searched.length ? `, and ${Scanned - Found.searched.length} more` : ""}` : "";
    const Skipped = Found.empty ? ` ${Found.empty} script${Found.empty === 1 ? "" : "s"} with no source were skipped.` : "";
    const Nothing = Scanned === 0 ? ` Nothing under ${Found.root || "there"} has any script source to search.` : "";

    return `No match in ${Scanned} script${Scanned === 1 ? "" : "s"}${Where}.${Skipped}${Nothing} find reads script source only, so text built at runtime, kept in an attribute or a property, or living in a script it requires instead will not match; search that script or read the instance with properties.`;
  }

  return `${Hits.join("\n")}${Found.more > 0 ? `\n${Found.more} more matches not shown; raise limit to see them.` : ""}`;
}

export type SourceAnswer = { error?: string; path?: string; total?: number; lines?: string[]; text?: string } | null;

export function SourceReport(Found: SourceAnswer) {
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

export type SelectAnswer = { error?: string; paths?: string[]; text?: string } | null;

export function SelectReport(Found: SelectAnswer) {
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

export type ApiAnswer = { error?: string; classes?: string[]; items?: string[]; enumName?: string; hits?: string[]; search?: string; className?: string; inherits?: string[]; creatable?: boolean; member?: string; properties: string[]; methods: string[]; events: string[]; subclasses?: string[]; shared: number } | null;

export function ApiReport(Found: ApiAnswer) {
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

  for (const [Label, Lines] of [["properties", Found.properties], ["methods", Found.methods], ["events", Found.events]] as [string, string[]][]) {
    if (Lines && Lines.length > 0) {
      Parts.push(`${Label}:`);
      Parts.push(Lines.map((Line: string) => `  ${Line}`).join("\n"));
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

export type ExecuteAnswer = { error?: string; line?: string; trace?: string; result?: unknown; output?: string[]; undo?: boolean } | null;

export function ExecuteReport(Found: ExecuteAnswer) {
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

export type LintAnswer = { error?: string; scripts?: { path: string; lines?: string[] }[]; skipped?: string[]; elsewhere?: string[] } | null;

export function LintReport(Found: LintAnswer) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  const Scripts = Found.scripts || [];
  const Lines = Scripts.map((Entry: { path: string; lines?: string[] }) => [Entry.path].concat((Entry.lines || []).map((Warning: string) => `  ${Warning}`)).join("\n"));

  if (Found.skipped && Found.skipped.length > 0) {
    Lines.push(`Could not check: ${Found.skipped.join(", ")}`);
  }

  if (Found.elsewhere && Found.elsewhere.length > 0) {
    Lines.push(`Not shown: warnings in ${Found.elsewhere.length} script${Found.elsewhere.length === 1 ? "" : "s"} these depend on (${Found.elsewhere.slice(0, 10).join(", ")}${Found.elsewhere.length > 10 ? ", ..." : ""}). Lint those paths to see them.`);
  }

  return Lines.length > 0 ? Lines.join("\n") : "No warnings.";
}







export function AskServerFor(Reach: Reacher, ReachIn: ReacherIn) {
  const Shared = StudioTools({
    Reach,
    ReachIn: <Found,>(Role: string, Kind: string, Input?: unknown, Timeout?: number): Promise<Found> => ReachIn<Found>(Role, Kind, Input, Timeout),
    Presence: async () => {
      const { Describe: Say } = await import("./StudioPresence.js");
      const { Presence } = await import("./Studio.js");
      const { StudioProcesses } = await import("./StudioPresence.js");

      return Say({
        ...Presence(),
        processes: await StudioProcesses(),
      });
    },
    LiveSession: async () => {
      const { RuntimeLive, Presence } = await import("./Studio.js");
      const Now = Presence();

      return RuntimeLive() ? {Players: typeof Now.clients === "number" ? Now.clients : null, Ready: Now.ready || 0, Settled: Now.settled || 0, Able: Now.canRun === true} : null;
    },
  });

  return createSdkMcpServer({
    name: AskServerName,
    version: "1.0.0",
    tools: [
      ...Shared.map((Entry) => tool(Entry.Name, Entry.Description, Entry.Schema, Entry.Run)),
    ],
  });
}
type ProfiledFunction = Record<string, unknown>;

// Ranks what Roblox's script profiler recorded. Each function's total includes the functions it called,
// so the per-script figure is each script's busiest function rather than a sum, which would count time twice.
export function ProfileReport(Found: { error?: string; json?: string } | null, Seconds: number): string {
  if (!Found) {
    return "The play session did not answer.";
  }

  if (Found.error || !Found.json) {
    return Found.error || "The profiler returned nothing.";
  }

  let Data: Record<string, unknown>;

  try {
    Data = JSON.parse(Found.json) as Record<string, unknown>;
  } catch {
    return `The profiler sent data Claudio could not read: ${Found.json.slice(0, 300)}`;
  }

  const Functions = (Array.isArray(Data.Functions) ? Data.Functions : []) as ProfiledFunction[];

  if (Functions.length === 0) {
    return `The profiler recorded no script activity in ${Seconds}s. Play the game or make it busy while it runs. Fields it sent: ${Object.keys(Data).join(", ")}.`;
  }

  const Time = (Entry: ProfiledFunction) => Number(Entry.TotalDuration ?? Entry.Duration ?? 0) || 0;
  const Where = (Entry: ProfiledFunction) => String(Entry.Source ?? Entry.Script ?? "unknown script");
  const Label = (Entry: ProfiledFunction) => `${String(Entry.Name || "anonymous")}${Entry.Line !== undefined ? ` (line ${Entry.Line})` : ""}`;
  const Unit = (Value: number) => `${(Value / 1000).toFixed(1)} ms`;
  // In a run-mode playtest the server shares Studio's own process, so plugins and engine code show up too.
  // Keep the game's scripts, whose sources are paths inside the place, and total the rest on one line.
  const Services = /^(Workspace|ServerScriptService|ServerStorage|ReplicatedStorage|ReplicatedFirst|StarterPlayer|StarterGui|StarterPack|Players|Lighting|SoundService|Teams|Chat|TextChatService)\./;
  const Game = Functions.filter((Entry) => Services.test(Where(Entry)));
  const Others = Functions.filter((Entry) => !Services.test(Where(Entry))).reduce((Most, Entry) => Math.max(Most, Time(Entry)), 0);
  const Ranked = [...Game].sort((Left, Right) => Time(Right) - Time(Left));
  const Scripts = new Map<string, number>();

  if (Game.length === 0) {
    return `None of the game's scripts used measurable CPU in ${Seconds}s; only Studio and plugins did (busiest ${Unit(Others)}). Play the game or make it busy while it runs, and use a play mode playtest rather than run mode to leave Studio's own work out.`;
  }

  for (const Entry of Game) {
    Scripts.set(Where(Entry), Math.max(Scripts.get(Where(Entry)) || 0, Time(Entry)));
  }

  const Lines = [`Game script CPU on the server over ${Seconds}s. Times include the functions each one called.${Others > 0 ? ` Studio and plugins also ran, busiest at ${Unit(Others)}, and are left out.` : ""}`, "", "Scripts by their busiest function:"];

  for (const [Name, Spent] of [...Scripts.entries()].sort((Left, Right) => Right[1] - Left[1]).slice(0, 15)) {
    Lines.push(`  ${Unit(Spent)}  ${Name}`);
  }

  Lines.push("", "Busiest functions:");

  for (const Entry of Ranked.slice(0, 20)) {
    Lines.push(`  ${Unit(Time(Entry))}  ${Label(Entry)} in ${Where(Entry)}`);
  }

  return Lines.join("\n");
}
