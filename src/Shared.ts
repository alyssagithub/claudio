import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";

const SharedFile = path.join(os.homedir(), ".claudio", "shared.json");
const Pictures: Record<string, string> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
};

function ReadShared(): string[] {
  try {
    const Saved = JSON.parse(fs.readFileSync(SharedFile, "utf8"));

    return Array.isArray(Saved) ? Saved.filter((Entry) => typeof Entry === "string") : [];
  } catch {
    return [];
  }
}

export function ShareFiles(Paths: string[]) {
  const Shared = ReadShared();
  const Lines: string[] = [];
  const Images: { type: "image"; data: string; mimeType: string }[] = [];

  for (const Given of Paths) {
    const Full = path.resolve(Given);
    let Stat: fs.Stats;

    try {
      Stat = fs.statSync(Full);
    } catch {
      Lines.push(`Missing ${Full}: there is no file there.`);
      continue;
    }

    if (!Stat.isFile()) {
      Lines.push(`Missing ${Full}: that is a folder, not a file.`);
      continue;
    }

    Shared.push(Full);
    Lines.push(`Shared ${Full} (${Stat.size >= 1048576 ? `${(Stat.size / 1048576).toFixed(1)} MB` : Stat.size >= 1024 ? `${Math.round(Stat.size / 1024)} KB` : `${Stat.size} B`})`);

    const Kind = Pictures[path.extname(Full).toLowerCase()];

    if (Kind && Images.length === 0 && Stat.size <= 5 * 1024 * 1024) {
      Images.push({type: "image", data: fs.readFileSync(Full).toString("base64"), mimeType: Kind});
    }
  }

  fs.mkdirSync(path.dirname(SharedFile), {recursive: true});
  fs.writeFileSync(SharedFile, JSON.stringify([...new Set(Shared)].slice(-500)));

  return {Lines, Images};
}

export function OpenShared(Given: string, Reveal: boolean): string | null {
  const Full = path.resolve(Given);

  if (!ReadShared().includes(Full)) {
    return "Only files Claude shared in a chat can be opened from here.";
  }

  if (!fs.existsSync(Full)) {
    return "That file is not there any more.";
  }

  if (process.platform !== "win32") {
    execFile(process.platform === "darwin" ? "open" : "xdg-open", Reveal ? [path.dirname(Full)] : [Full], () => {});
    return null;
  }

  execFile("explorer.exe", Reveal ? [`/select,${Full}`] : [Full], {windowsHide: true}, () => {});

  return null;
}
