import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { Presence } from "./Studio.js";
import { StudioProcesses } from "./StudioPresence.js";

const BuiltInPluginsOff = /(<bool name="LoadAllBuiltinPluginsInRunModes">)false(<\/bool>)/;

function SettingsFile(): string | null {
  const Root = path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local"), "Roblox");

  try {
    const Newest = fs.readdirSync(Root)
      .map((Name) => Name.match(/^GlobalSettings_(\d+)\.xml$/))
      .filter((Found) => Found !== null)
      .sort((Left, Right) => Number(Right[1]) - Number(Left[1]))[0];

    return Newest ? path.join(Root, Newest[0]) : null;
  } catch {
    return null;
  }
}

async function TurnOnBuiltInPlugins(File: string): Promise<boolean> {
  const Text = fs.readFileSync(File, "utf8");

  if (!BuiltInPluginsOff.test(Text)) {
    return true;
  }

  if ((await StudioProcesses()).length > 0) {
    return false;
  }

  const Temporary = `${File}.claudio-writing`;

  try {
    fs.writeFileSync(Temporary, Text.replace(BuiltInPluginsOff, "$1true$2"));
    fs.renameSync(Temporary, File);
  } catch (Error) {
    fs.rmSync(Temporary, {force: true});
    throw Error;
  }

  console.log("Turned on Load All Built-In Plugins in Test Mode, so Claudio's panel stays docked in playtests.");

  return true;
}

export function KeepBuiltInPluginsLoaded() {
  if (process.platform !== "win32") {
    return;
  }

  const File = SettingsFile();

  if (!File) {
    return;
  }

  let WasSeen = true;
  let LastChecked = 0;
  let Busy = false;

  setInterval(async () => {
    const Seen = Date.now() - Presence().lastSeen < 10000;
    const JustClosed = WasSeen && !Seen;

    WasSeen = Seen;

    if (Busy || Seen || (!JustClosed && Date.now() - LastChecked < 30000)) {
      return;
    }

    Busy = true;
    LastChecked = Date.now();

    try {
      await TurnOnBuiltInPlugins(File);
    } catch (Error) {
      console.error(`Could not turn on Load All Built-In Plugins in Test Mode: ${(Error as Error).message}`);
    }

    Busy = false;
  }, 2000);
}
