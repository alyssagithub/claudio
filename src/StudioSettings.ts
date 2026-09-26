import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { Presence } from "./Studio.js";
import { StudioProcesses } from "./StudioPresence.js";

const BuiltInPlugins = /(<bool name="LoadAllBuiltinPluginsInRunModes">)(true|false)(<\/bool>)/;

let Wanted: boolean | null = null;
let Watching: NodeJS.Timeout | undefined;

function SettingsFile(): string | null {
  if (process.platform !== "win32") {
    return null;
  }

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

export function ReadBuiltInPlugins(): boolean | null {
  const File = SettingsFile();

  if (!File) {
    return null;
  }

  try {
    const Found = fs.readFileSync(File, "utf8").match(BuiltInPlugins);

    return Found ? Found[2] === "true" : null;
  } catch {
    return null;
  }
}

function Write(File: string, On: boolean) {
  const Text = fs.readFileSync(File, "utf8");

  if (!BuiltInPlugins.test(Text)) {
    throw new Error("Studio's settings file has no Load All Built-In Plugins in Test Mode entry");
  }

  const Temporary = `${File}.claudio-writing`;

  try {
    fs.writeFileSync(Temporary, Text.replace(BuiltInPlugins, `$1${On}$3`));
    fs.renameSync(Temporary, File);
  } catch (Error) {
    fs.rmSync(Temporary, {force: true});
    throw Error;
  }
}

export function SetBuiltInPlugins(On: boolean) {
  const File = SettingsFile();

  if (!File) {
    throw new Error("Studio's settings file was not found");
  }

  Write(File, On);
  Wanted = On;

  if (Watching) {
    return;
  }

  let Busy = false;

  Watching = setInterval(async () => {
    if (Busy || Date.now() - Presence().lastSeen < 10000) {
      return;
    }

    Busy = true;

    try {
      if ((await StudioProcesses()).length === 0) {
        if (Wanted !== null && ReadBuiltInPlugins() !== Wanted) {
          Write(File, Wanted);
        }

        clearInterval(Watching);
        Watching = undefined;
        Wanted = null;
      }
    } catch (Error) {
      console.error(`Could not keep Load All Built-In Plugins in Test Mode as it was set: ${(Error as Error).message}`);
    }

    Busy = false;
  }, 2000);
}
