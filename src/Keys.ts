import path from "node:path";
import { spawn } from "node:child_process";
import type { ChildProcess } from "node:child_process";
import { fileURLToPath } from "node:url";

const WatchPath = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "Keys.ps1");

type ReturnPress = { at: number; shift: boolean };

let LastReturn: ReturnPress | null = null;
let LastCopy = 0;
let Watcher: ChildProcess | null = null;
let Ready = false;
let Failed: string | null = null;
let Stopping: NodeJS.Timeout | null = null;

export function WatchReturn() {
  if (Stopping) {
    clearTimeout(Stopping);
    Stopping = null;
  }

  if (process.platform !== "win32" || Watcher) {
    return;
  }

  Ready = false;
  Failed = null;

  const Started = spawn("powershell", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", WatchPath], {
    stdio: ["pipe", "pipe", "pipe"],
    windowsHide: true,
  });

  Watcher = Started;

  let Held = "";

  Started.stdout!.on("data", (Chunk: Buffer) => {
    Held += Chunk.toString("utf8");

    const Lines = Held.split(/\r?\n/);

    Held = Lines.pop() || "";

    for (const Line of Lines) {
      try {
        const Parsed = JSON.parse(Line) as Partial<ReturnPress> & { ready?: boolean; key?: string };

        if (Parsed.ready === true) {
          Ready = true;
        }

        if (typeof Parsed.at === "number" && Parsed.key === "copy") {
          LastCopy = Parsed.at;
        } else if (typeof Parsed.at === "number" && typeof Parsed.shift === "boolean") {
          LastReturn = {
            at: Parsed.at,
            shift: Parsed.shift,
          };
        }
      } catch {
        continue;
      }
    }
  });

  Started.on("error", (Error) => {
    if (Watcher !== Started) {
      return;
    }

    Watcher = null;
    Ready = false;
    Failed = `The key watcher could not start: ${Error.message}`;
  });
  Started.stdin!.on("error", () => {});

  Started.stderr!.on("data", (Chunk: Buffer) => {
    Failed = Chunk.toString("utf8").trim().slice(0, 300);
  });

  Started.on("exit", (Code) => {
    if (Watcher !== Started) {
      return;
    }

    Watcher = null;
    Ready = false;

    if (Code !== 0 && Code !== null && !Failed) {
      Failed = `the key watcher exited with code ${Code}`;
    }
  });
}

export function StopWatchingReturn(Now?: boolean) {
  if (Stopping) {
    clearTimeout(Stopping);
    Stopping = null;
  }

  const Kill = () => {
    Stopping = null;

    if (Watcher) {
      Watcher.kill();
      Watcher = null;
      Ready = false;
    }
  };

  if (Now) {
    Kill();

    return;
  }

  Stopping = setTimeout(Kill, 3000);
}

export function DescribeReturn() {
  return {
    watching: Watcher !== null && Ready,
    trouble: Failed,
    at: LastReturn ? LastReturn.at : 0,
    shift: LastReturn ? LastReturn.shift : false,
    copyAt: LastCopy,
    now: Date.now(),
  };
}

process.on("exit", () => StopWatchingReturn(true));