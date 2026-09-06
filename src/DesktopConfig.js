import fs from "node:fs";
import path from "node:path";
import { DesktopConfigPath } from "./Config.js";

export const RobloxServer = {
  command: process.platform === "win32" ? "cmd" : "npx",
  args: process.platform === "win32"
    ? ["/c", "npx", "-y", "@chrrxs/robloxstudio-mcp@latest", "--auto-install-plugin"]
    : ["-y", "@chrrxs/robloxstudio-mcp@latest", "--auto-install-plugin"],
};

// Three outcomes, not two. Treating an unreadable config as a missing one
// overwrites whatever the person already had in it.
export function ReadConfig() {
  let Text;

  try {
    Text = fs.readFileSync(DesktopConfigPath, "utf8");
  } catch (Error) {
    return Error.code === "ENOENT" ? { Missing: true } : { Unreadable: Error.message };
  }

  try {
    return { Config: JSON.parse(Text.replace(/^﻿/, "")) };
  } catch (Error) {
    return { Unreadable: Error.message };
  }
}

// Claude Desktop reads this file while we write it, so land it in one rename
// rather than leaving a window where it is half a document.
export function WriteConfig(Config) {
  const Temporary = `${DesktopConfigPath}.claudio-writing`;

  fs.mkdirSync(path.dirname(DesktopConfigPath), { recursive: true });

  try {
    fs.writeFileSync(Temporary, JSON.stringify(Config, null, 2));
    fs.renameSync(Temporary, DesktopConfigPath);
  } catch (Error) {
    fs.rmSync(Temporary, { force: true });

    throw Error;
  }
}
