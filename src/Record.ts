import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import { PNG } from "pngjs";
import jpeg from "jpeg-js";

const FramesScript = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "Frames.ps1");
const ClipFolder = path.join(os.homedir(), ".claudio", "recordings");

// Studio writes each recording to this folder and deletes it within minutes.
function CaptureFolder(): string {
  return path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local"), "Roblox", "tmp-capture-storage");
}

// Copies the newest clip Studio wrote since the recording began to a lasting place, and returns its path.
export function KeepClip(Since: number): string | null {
  let Newest: { File: string; At: number } | null = null;

  try {
    for (const Name of fs.readdirSync(CaptureFolder())) {
      const File = path.join(CaptureFolder(), Name);
      const At = fs.statSync(File).mtimeMs;

      if (At >= Since - 1000 && (!Newest || At > Newest.At)) {
        Newest = {File, At};
      }
    }
  } catch {
    return null;
  }

  if (!Newest) {
    return null;
  }

  fs.mkdirSync(ClipFolder, {recursive: true});

  const Kept = path.join(ClipFolder, `record-${new Date().toISOString().replace(/[:.]/g, "-")}.mp4`);

  fs.copyFileSync(Newest.File, Kept);

  // Old clips are not needed for long; keep the twenty newest.
  const Old = fs.readdirSync(ClipFolder).filter((Name) => Name.endsWith(".mp4")).sort().reverse().slice(20);

  for (const Name of Old) {
    fs.rmSync(path.join(ClipFolder, Name), {force: true});
  }

  return Kept;
}

export function PullFrames(Clip: string, Times: number[]): Promise<{ Length: number; Files: string[] }> {
  const Folder = fs.mkdtempSync(path.join(os.tmpdir(), "claudio-frames-"));

  return new Promise((Resolve, Reject) => {
    execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", FramesScript, "-Video", Clip, "-OutFolder", Folder, "-Seconds", Times.map((At) => At.toFixed(3)).join(",")], {
      timeout: 120000,
      windowsHide: true,
    }, (Trouble, Output, Problem) => {
      const Lines = String(Output || "").split(/\r?\n/).map((Line) => Line.trim()).filter(Boolean);
      const Length = Number((Lines.find((Line) => Line.startsWith("length ")) || "").slice(7));
      const Files = Lines.filter((Line) => Line.toLowerCase().endsWith(".jpg") && fs.existsSync(Line));

      if (Trouble && Files.length === 0) {
        Reject(new Error(String(Problem || Trouble.message).trim().slice(0, 400)));

        return;
      }

      Resolve({Length: Number.isFinite(Length) ? Length : 0, Files});
    });
  });
}

export function ClipLength(Clip: string): Promise<number> {
  return PullFrames(Clip, [0]).then((Found) => Found.Length);
}

// Lays the frames out in a grid, reading left to right then top to bottom, each scaled to Width pixels
// wide by averaging the source pixels it covers.
export function Sheet(Files: string[], Width = 300): Buffer {
  const Frames = Files.map((File) => jpeg.decode(fs.readFileSync(File), {useTArray: true}));
  const Columns = Math.min(4, Math.max(1, Math.ceil(Math.sqrt(Frames.length))));
  const Rows = Math.ceil(Frames.length / Columns);
  const Scale = Width / Frames[0].width;
  const Height = Math.round(Frames[0].height * Scale);
  const Gap = 4;
  const Out = new PNG({width: Columns * Width + (Columns - 1) * Gap, height: Rows * Height + (Rows - 1) * Gap});

  Out.data.fill(255);

  Frames.forEach((Frame, Index) => {
    const Left = (Index % Columns) * (Width + Gap);
    const Top = Math.floor(Index / Columns) * (Height + Gap);
    const Step = Frame.width / Width;

    for (let Y = 0; Y < Height; Y += 1) {
      for (let X = 0; X < Width; X += 1) {
        const FromX = Math.floor(X * Step);
        const FromY = Math.floor(Y * Step);
        const Span = Math.max(1, Math.floor(Step));
        let Red = 0;
        let Green = 0;
        let Blue = 0;
        let Count = 0;

        for (let DY = 0; DY < Span && FromY + DY < Frame.height; DY += 1) {
          for (let DX = 0; DX < Span && FromX + DX < Frame.width; DX += 1) {
            const At = ((FromY + DY) * Frame.width + FromX + DX) * 4;

            Red += Frame.data[At];
            Green += Frame.data[At + 1];
            Blue += Frame.data[At + 2];
            Count += 1;
          }
        }

        const To = ((Top + Y) * Out.width + Left + X) * 4;

        Out.data[To] = Red / Count;
        Out.data[To + 1] = Green / Count;
        Out.data[To + 2] = Blue / Count;
        Out.data[To + 3] = 255;
      }
    }
  });

  for (const File of Files) {
    fs.rmSync(File, {force: true});
  }

  return PNG.sync.write(Out);
}
