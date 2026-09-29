import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { PNG } from "pngjs";
import jpeg from "jpeg-js";

const Runnable = /\.(exe|bat|cmd|com|ps1|psm1|vbs|vbe|js|jse|wsf|wsh|msi|msp|lnk|scr|hta|jar|reg|cpl|pif|scf|url|appref-ms)$/i;

function Launch(Target: string, Reveal: boolean) {
  if (process.platform === "win32") {
    execFile("explorer.exe", Reveal ? [`/select,${Target}`] : [Target], {windowsHide: true}, () => {});
    return;
  }

  execFile(process.platform === "darwin" ? "open" : "xdg-open", [Reveal ? path.dirname(Target) : Target], () => {});
}

export function ProbePaths(Paths: unknown[]): Record<string, "file" | "folder"> {
  const Found: Record<string, "file" | "folder"> = {};

  for (const Given of Paths.slice(0, 200)) {
    if (typeof Given !== "string" || !path.isAbsolute(Given)) {
      continue;
    }

    try {
      Found[Given] = fs.statSync(Given).isDirectory() ? "folder" : "file";
    } catch {
      continue;
    }
  }

  return Found;
}

export function OpenPath(Given: string, Reveal: boolean): string | null {
  if (!path.isAbsolute(Given) || !fs.existsSync(Given)) {
    return "There is nothing at that path.";
  }

  if (!Reveal && Runnable.test(Given)) {
    return "That file runs a program, so Claudio only shows it in its folder.";
  }

  Launch(path.resolve(Given), Reveal);

  return null;
}

export function ReadPicture(Given: string): { width: number; height: number; pixels: string } | null {
  try {
    const Bytes = fs.readFileSync(Given);
    const Decoded = /\.png$/i.test(Given) ? PNG.sync.read(Bytes) : jpeg.decode(Bytes, {useTArray: true, formatAsRGBA: true});
    const Scale = Math.min(1, 1024 / Decoded.width, 1024 / Decoded.height);
    const Width = Math.max(1, Math.round(Decoded.width * Scale));
    const Height = Math.max(1, Math.round(Decoded.height * Scale));
    const Source = Buffer.from(Decoded.data.buffer, Decoded.data.byteOffset, Decoded.data.byteLength);
    const Pixels = Buffer.alloc(Width * Height * 4);

    for (let Y = 0; Y < Height; Y += 1) {
      for (let X = 0; X < Width; X += 1) {
        const From = (Math.min(Decoded.height - 1, Math.floor(Y / Scale)) * Decoded.width + Math.min(Decoded.width - 1, Math.floor(X / Scale))) * 4;

        Source.copy(Pixels, (Y * Width + X) * 4, From, From + 4);
      }
    }

    return {width: Width, height: Height, pixels: Pixels.toString("base64")};
  } catch {
    return null;
  }
}

export function SavePicture(Width: number, Height: number, Pixels: string, Open: boolean): string {
  const Picture = new PNG({width: Width, height: Height});
  const Folder = path.join(os.homedir(), ".claudio", "pictures");
  const Saved = path.join(Folder, `picture-${new Date().toISOString().replace(/[:.]/g, "-")}.png`);

  Buffer.from(Pixels, "base64").copy(Picture.data);
  fs.mkdirSync(Folder, {recursive: true});
  fs.writeFileSync(Saved, PNG.sync.write(Picture));

  if (Open) {
    Launch(Saved, false);
  }

  return Saved;
}
