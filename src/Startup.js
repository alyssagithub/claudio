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

export async function InstallStartup(Port) {
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

  console.log(`Installed ${LauncherPath}`);

  await RestartBridge(Port);
}

export function LaunchHidden() {
  if (!fs.existsSync(LauncherPath)) {
    throw new Error("Run `claudio install-startup` first.");
  }

  const Launched = execFile("wscript.exe", [LauncherPath], { detached: true });

  Launched.on("error", (Error) => {
    console.error("Could not start the bridge launcher: " + Error.message);
  });
  Launched.unref();
}

async function PortIsBusy(Port) {
  try {
    await fetch(`http://127.0.0.1:${Port || DefaultPort}/health`);

    return true;
  } catch {
    return false;
  }
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

  await StopBridge(Port);

  // Launching while the old one still holds the port just kills the new
  // process, and the machine quietly carries on with the build being replaced.
  for (let Attempt = 0; Attempt < 60; Attempt += 1) {
    if (!(await PortIsBusy(Port))) {
      LaunchHidden();

      for (let Wait = 0; Wait < 40; Wait += 1) {
        await new Promise((Resolve) => setTimeout(Resolve, 250));

        if (await PortIsBusy(Port)) {
          console.log(`Started the bridge hidden. Log: ${LogFile}`);

          return;
        }
      }

      throw new Error(`The bridge was launched but never answered on port ${Port || DefaultPort}. Check ${LogFile}.`);
    }

    await new Promise((Resolve) => setTimeout(Resolve, 250));
  }

  throw new Error(`The bridge on port ${Port || DefaultPort} would not stop, so a new one was not started. Close it and run \`claudio restart\` again.`);
}

export function UninstallStartup() {
  if (!fs.existsSync(LauncherPath)) {
    console.log("Startup launcher was not installed.");
    return;
  }

  fs.unlinkSync(LauncherPath);
  console.log(`Removed ${LauncherPath}. A bridge that is already running keeps running until you close it.`);
}
