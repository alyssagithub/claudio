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
    Parts.push(`Could not read: ${Found.unreadable.join(", ")}`);
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

export type FindAnswer = { error?: string; hits?: string[]; scanned?: number; more: number } | null;

export function FindReport(Found: FindAnswer) {
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

export type LintAnswer = { error?: string; scripts?: { path: string; lines?: string[] }[]; skipped?: string[] } | null;

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
    ],
  });
}