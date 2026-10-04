import { spawn, type ChildProcess } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import readline from "node:readline";
import { fileURLToPath } from "node:url";

const Script = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "DropZone.ps1");

type Dropped = { path: string; name: string; data?: string; mediaType?: string };

let Helper: ChildProcess | null = null;
const Waiting: Dropped[] = [];

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

    if (Kind !== "drop") {
      return;
    }

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
  });
  Made.on("exit", Stop);
  Made.on("error", Stop);
  Made.stdin!.on("error", Stop);
  Helper = Made;

  return Made;
}

export function SetDropArea(Area: { x: number; y: number; width: number; height: number } | null) {
  const Running = Area ? Started() : Helper;

  if (!Running) {
    return;
  }

  Running.stdin!.write(Area ? `rel ${Math.round(Area.x)} ${Math.round(Area.y)} ${Math.round(Area.width)} ${Math.round(Area.height)}\n` : "off\n");
}

export function TakeDropped(): Dropped[] {
  return Waiting.splice(0);
}

process.on("exit", () => {
  if (Helper) {
    Helper.kill();
  }
});
