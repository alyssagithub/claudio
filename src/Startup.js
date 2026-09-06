import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import { DefaultPort, LogFile } from "./Config.js";

const LauncherPath = path.join(
  process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming"),
  "Microsoft", "Windows", "Start Menu", "Programs", "Startup", "Claudio Bridge.vbs",
);

function VisualBasicString(Value) {
  return `"${Value.replace(/"/g, '""')}"`;
}

export function InstallStartup() {
  if (process.platform !== "win32") {
    throw new Error("Startup install is only written for Windows so far.");
  }

  const CliPath = path.resolve(fileURLToPath(import.meta.url), "..", "..", "bin", "claudio.js");

  const Command = `cmd /c ""${process.execPath}" "${CliPath}" >> "${LogFile}" 2>&1"`;

  fs.mkdirSync(path.dirname(LogFile), { recursive: true });
  fs.writeFileSync(LauncherPath, [
    `Set Shell = CreateObject("WScript.Shell")`,
    `Shell.Run ${VisualBasicString(Command)}, 0, False`,
    "",
  ].join("\r\n"));

  LaunchHidden();
  console.log(`Installed ${LauncherPath}`);
  console.log(`The bridge now starts hidden at logon and is starting now. Log: ${LogFile}`);
}

export function LaunchHidden() {
  if (!fs.existsSync(LauncherPath)) {
    throw new Error("Run `claudio install-startup` first.");
  }

  execFile("wscript.exe", [LauncherPath], { detached: true, stdio: "ignore" }).unref();
}

export async function StopBridge(Port) {
  try {
    await fetch(`http://127.0.0.1:${Port || DefaultPort}/quit`, { method: "POST" });
    console.log("Asked the running bridge to quit.");
    return true;
  } catch {
    console.log("No bridge was running.");
    return false;
  }
}

export async function RestartBridge(Port) {
  if (!fs.existsSync(LauncherPath)) {
    throw new Error("Run `claudio install-startup` first.");
  }

  if (await StopBridge(Port)) {
    for (let Attempt = 0; Attempt < 20; Attempt += 1) {
      await new Promise((Resolve) => setTimeout(Resolve, 250));

      try {
        await fetch(`http://127.0.0.1:${Port || DefaultPort}/health`);
      } catch {
        break;
      }
    }
  }

  LaunchHidden();
  console.log(`Started the bridge hidden. Log: ${LogFile}`);
}

export function UninstallStartup() {
  if (!fs.existsSync(LauncherPath)) {
    console.log("Startup launcher was not installed.");
    return;
  }

  fs.unlinkSync(LauncherPath);
  console.log(`Removed ${LauncherPath}. A bridge that is already running keeps running until you close it.`);
}
