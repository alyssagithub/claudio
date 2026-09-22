import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SettingPrefix = "Claudio_";

function SettingsFiles() {
  const Root = path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local"), "Roblox");
  const Found: string[] = [];

  let Accounts: string[] = [];

  try {
    Accounts = fs.readdirSync(Root);
  } catch {
    return Found;
  }

  for (const Account of Accounts) {
    const File = path.join(Root, Account, "InstalledPlugins", "0", "settings.json");

    if (fs.existsSync(File)) {
      Found.push(File);
    }
  }

  return Found;
}

function ReadSettings(File: string): Record<string, unknown> | null {
  try {
    const Parsed: unknown = JSON.parse(fs.readFileSync(File, "utf8").replace(/^﻿/, ""));

    return Parsed && typeof Parsed === "object" && !Array.isArray(Parsed) ? Parsed as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

export function ReadPluginSetting(Key: string): unknown {
  for (const File of SettingsFiles()) {
    const Settings = ReadSettings(File);

    if (Settings && Settings[SettingPrefix + Key] !== undefined) {
      return Settings[SettingPrefix + Key];
    }
  }

  return undefined;
}

export function WritePluginSetting(Key: string, Value: unknown): number {
  const Files = SettingsFiles();
  let Written = 0;

  for (const File of Files) {
    const Settings = ReadSettings(File);

    if (!Settings) {
      continue;
    }

    if (Settings[SettingPrefix + Key] === Value) {
      Written += 1;
      continue;
    }

    Settings[SettingPrefix + Key] = Value;

    const Temporary = `${File}.claudio-writing`;

    try {
      fs.writeFileSync(Temporary, JSON.stringify(Settings, null, 2));
      fs.renameSync(Temporary, File);
      Written += 1;
    } catch (Error) {
      fs.rmSync(Temporary, {force: true});
      console.error(`Could not write the plugin setting ${Key}: ${(Error as NodeJS.ErrnoException).message}`);
    }
  }

  return Written;
}

export function ForgetPluginSettings(): number {
  let Cleared = 0;

  for (const File of SettingsFiles()) {
    const Settings = ReadSettings(File);
    const Keys = Object.keys(Settings || {}).filter((Key) => Key.startsWith("Claudio"));

    if (!Settings || Keys.length === 0) {
      continue;
    }

    for (const Key of Keys) {
      delete Settings[Key];
    }

    const Temporary = `${File}.claudio-writing`;

    try {
      fs.writeFileSync(Temporary, JSON.stringify(Settings, null, 2));
      fs.renameSync(Temporary, File);
      Cleared += Keys.length;
    } catch (Error) {
      fs.rmSync(Temporary, {force: true});
      console.error(`Could not clear the plugin's settings in ${File}: ${(Error as NodeJS.ErrnoException).message}`);
    }
  }

  return Cleared;
}