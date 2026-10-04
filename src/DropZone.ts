import { spawn, type ChildProcess } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import readline from "node:readline";
import { fileURLToPath } from "node:url";

const Script = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "DropZone.ps1");

type Dropped = { path: string; name: string; data?: string; mediaType?: string };

let Helper: ChildProcess | null = null;
let Dragging = "off";
const Waiting: Dropped[] = [];
const Listeners = new Set<() => void>();

function Started(): ChildProcess | null {
  if (process.platform !== "win32") {
    return null;
  }

  if (Helper) {
    return Helper;
  }

  const Made = spawn("powershell.exe", ["-NoProfile", "-NonInteractive", "-STA", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", Script], {
    windowsHide: true,
    stdio: ["pipe", "pipe", "ignore"],
  });
  const Stop = () => {
    if (Helper === Made) {
      Helper = null;
    }
  };

  readline.createInterface({input: Made.stdout!}).on("line", (Line) => {
    const [Kind, ...Paths] = Line.split("\t");

    if (Kind === "drag") {
      Dragging = Paths[0] || "off";

      for (const Wake of [...Listeners]) {
        Wake();
      }

      return;
    }

    if (Kind !== "drop") {
      return;
    }

    Dragging = "off";

    for (const Given of Paths) {
      if (!fs.existsSync(Given) || !fs.statSync(Given).isFile()) {
        continue;
      }

      const Lower = Given.toLowerCase();
      const Picture = (Lower.endsWith(".png") || Lower.endsWith(".jpg") || Lower.endsWith(".jpeg")) && fs.statSync(Given).size < 10 * 1024 * 1024;

      Waiting.push({
        path: Given,
        name: path.basename(Given),
        data: Picture ? fs.readFileSync(Given).toString("base64") : undefined,
        mediaType: Picture ? (Lower.endsWith(".png") ? "image/png" : "image/jpeg") : undefined,
      });
    }

    for (const Wake of [...Listeners]) {
      Wake();
    }
  });
  Made.on("exit", Stop);
  Made.on("error", Stop);
  Made.stdin!.on("error", Stop);
  Helper = Made;

  return Made;
}

export function SetDropArea(Area: { x: number; y: number; width: number; height: number } | null) {
  const Running = Started();

  if (!Running) {
    return;
  }

  Running.stdin!.write(Area ? `rel ${Math.round(Area.x)} ${Math.round(Area.y)} ${Math.round(Area.width)} ${Math.round(Area.height)}\n` : "off\n");
}

export function TakeDropped(Milliseconds: number, Seen: string): Promise<{ files: Dropped[]; dragging: string }> {
  if (Waiting.length > 0 || Milliseconds <= 0 || Dragging !== Seen) {
    return Promise.resolve({files: Waiting.splice(0), dragging: Dragging});
  }

  return new Promise((Resolve) => {
    const Wake = () => {
      clearTimeout(Timer);
      Listeners.delete(Wake);
      Resolve({files: Waiting.splice(0), dragging: Dragging});
    };
    const Timer = setTimeout(Wake, Milliseconds);

    Listeners.add(Wake);
  });
}

process.on("exit", () => {
  if (Helper) {
    Helper.kill();
  }
});
