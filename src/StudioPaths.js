import fs from "node:fs";
import os from "node:os";
import path from "node:path";

export function GetPluginsFolder() {
  const Candidates = process.platform === "win32"
    ? [path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local"), "Roblox", "Plugins")]
    : [
      path.join(os.homedir(), "Documents", "Roblox", "Plugins"),
      path.join(os.homedir(), "Library", "Application Support", "Roblox", "Plugins"),
    ];

  for (const Candidate of Candidates) {
    if (fs.existsSync(Candidate)) {
      return Candidate;
    }
  }

  return Candidates[0];
}
