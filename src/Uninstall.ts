import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { DefaultPort, PluginFileName } from "./Config.js";
import { GetPluginsFolder } from "./StudioPaths.js";
import { StopBridge, UninstallStartup } from "./Startup.js";
import { EnsureToken } from "./Token.js";
import { ForgetPluginSettings } from "./PluginSettings.js";

async function Remove(Target: string, Label: string, Removed: string[], Kept: string[]): Promise<void> {
  if (!fs.existsSync(Target)) {
    Kept.push(`${Label} was not there`);
    return;
  }

  for (let Attempt = 1; Attempt <= 12; Attempt += 1) {
    try {
      fs.rmSync(Target, {
        recursive: true,
        force: true,
      });
      Removed.push(`${Label} (${Target})`);
      return;
    } catch (Error) {
      if (Attempt === 12) {
        Kept.push(`${Label} could not be removed: ${(Error as NodeJS.ErrnoException).message}`);
        return;
      }

      await new Promise((Resolve) => setTimeout(Resolve, 300));
    }
  }
}

export async function RunUninstall() {
  const Removed: string[] = [];
  const Kept: string[] = [];

  const Port = Number(process.env.CLAUDIO_PORT || DefaultPort);

  if (await StopBridge(Port)) {
    for (let Attempt = 0; Attempt < 20; Attempt += 1) {
      await new Promise((Resolve) => setTimeout(Resolve, 250));

      try {
        await fetch(`http://127.0.0.1:${Port}/health`, {
          headers: {"X-Claudio-Token": EnsureToken()},
        });
      } catch {
        break;
      }
    }
  }

  const Cleared = ForgetPluginSettings();

  if (Cleared > 0) {
    Removed.push(`${Cleared} Claudio settings from Studio, including the bridge key`);
  }

  try {
    UninstallStartup();
  } catch (Error) {
    Kept.push(`the startup launcher could not be removed: ${(Error as NodeJS.ErrnoException).message}`);
  }

  await Remove(path.join(GetPluginsFolder(), PluginFileName), "the Studio plugin", Removed, Kept);
  fs.rmSync(path.join(GetPluginsFolder(), `${PluginFileName}.claudio-writing`), {force: true});
  await Remove(path.join(os.homedir(), ".claudio"), "Claudio's own folder", Removed, Kept);

  console.log("Removed:");

  for (const Line of Removed.length > 0 ? Removed : ["nothing, it was already gone"]) {
    console.log(`  - ${Line}`);
  }

  if (Kept.length > 0) {
    console.log("\nSkipped:");

    for (const Line of Kept) {
      console.log(`  - ${Line}`);
    }
  }

  console.log("\nLeft alone, because they are yours rather than Claudio's:");
  console.log("  - your chats and their transcripts in ~/.claude, and their entries in the desktop app's chat list");
  console.log("  - your Claude Code login");
  console.log("  - any claudio entry you added to Claude Code or the desktop app's MCP config, since Claudio never wrote one");

  console.log("\nLast step, which has to be separate because it deletes this command:");
  console.log("  npm uninstall -g claudio");
}