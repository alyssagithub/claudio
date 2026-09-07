import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SettingPrefix = "Claudio_";

function SettingsFiles() {
  const Root = path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local"), "Roblox");
  const Found = [];

  let Accounts = [];

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

function ReadSettings(File) {
  try {
    const Parsed = JSON.parse(fs.readFileSync(File, "utf8").replace(/^﻿/, ""));

    return Parsed && typeof Parsed === "object" && !Array.isArray(Parsed) ? Parsed : null;
  } catch {
    return null;
  }
}

export function WritePluginSetting(Key, Value) {
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
      fs.rmSync(Temporary, { force: true });
      console.error(`Could not write the plugin setting ${Key}: ${Error.message}`);
    }
  }

  return Written;
}

export function ForgetPluginSetting(Key) {
  for (const File of SettingsFiles()) {
    const Settings = ReadSettings(File);

    if (!Settings || Settings[SettingPrefix + Key] === undefined) {
      continue;
    }

    delete Settings[SettingPrefix + Key];

    const Temporary = `${File}.claudio-writing`;

    try {
      fs.writeFileSync(Temporary, JSON.stringify(Settings, null, 2));
      fs.renameSync(Temporary, File);
    } catch (Error) {
      fs.rmSync(Temporary, { force: true });
      console.error(`Could not clear the plugin setting ${Key}: ${Error.message}`);
    }
  }
}
