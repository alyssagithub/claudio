import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { DefaultPort, DesktopConfigPath, PluginFileName } from "./Config.js";
import { GetPluginsFolder } from "./StudioPaths.js";
import { StopBridge, UninstallStartup } from "./Startup.js";
import { EnsureToken } from "./Token.js";
import { ForgetPluginSetting } from "./PluginSettings.js";
import { ReadConfig, RobloxServer, WriteConfig } from "./DesktopConfig.js";

async function Remove(Target, Label, Removed, Kept) {
  if (!fs.existsSync(Target)) {
    Kept.push(`${Label} was not there`);
    return;
  }

  for (let Attempt = 1; Attempt <= 12; Attempt += 1) {
    try {
      fs.rmSync(Target, { recursive: true, force: true });
      Removed.push(`${Label} (${Target})`);
      return;
    } catch (Error) {
      if (Attempt === 12) {
        Kept.push(`${Label} could not be removed: ${Error.message}`);
        return;
      }

      await new Promise((Resolve) => setTimeout(Resolve, 300));
    }
  }
}

function DropMcpServer(Removed, Kept) {
  const Read = ReadConfig();

  if (Read.Unreadable || Read.Missing) {
    Kept.push("the Claude desktop config was not readable, so its MCP servers were left alone");
    return;
  }

  const Entry = Read.Config.mcpServers && Read.Config.mcpServers["robloxstudio-mcp"];

  if (!Entry) {
    Kept.push("no robloxstudio-mcp entry to remove");
    return;
  }

  const Same = Entry.command === RobloxServer.command
    && Array.isArray(Entry.args)
    && Entry.args.length === RobloxServer.args.length
    && Entry.args.every((Argument, At) => Argument === RobloxServer.args[At]);

  if (!Same) {
    Kept.push("the robloxstudio-mcp entry, because it is not the one Claudio wrote");
    return;
  }

  delete Read.Config.mcpServers["robloxstudio-mcp"];
  WriteConfig(Read.Config);
  Removed.push("the robloxstudio-mcp entry from the Claude desktop config");
}

export async function RunUninstall(AlsoMcp) {
  const Removed = [];
  const Kept = [];

  const Port = Number(process.env.CLAUDIO_PORT || DefaultPort);

  if (await StopBridge(Port)) {
    for (let Attempt = 0; Attempt < 20; Attempt += 1) {
      await new Promise((Resolve) => setTimeout(Resolve, 250));

      try {
        await fetch(`http://127.0.0.1:${Port}/health`, {
          headers: { "X-Claudio-Token": EnsureToken() },
        });
      } catch {
        break;
      }
    }
  }

  ForgetPluginSetting("BridgeToken");

  try {
    UninstallStartup();
  } catch (Error) {
    Kept.push(`the startup launcher could not be removed: ${Error.message}`);
  }

  await Remove(path.join(GetPluginsFolder(), PluginFileName), "the Studio plugin", Removed, Kept);
  fs.rmSync(path.join(GetPluginsFolder(), `${PluginFileName}.claudio-writing`), { force: true });
  await Remove(path.join(os.homedir(), ".claudio"), "Claudio's own folder", Removed, Kept);
  if (AlsoMcp) {
    DropMcpServer(Removed, Kept);
  }

  if (AlsoMcp) {
    await Remove(`${DesktopConfigPath}.claudio-backup`, "the config backup Claudio made", Removed, Kept);
  } else {
    Kept.push("the config backup, since the robloxstudio-mcp entry is still there");
  }

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

  console.log("\nLeft alone, because they belong to Claude Code rather than Claudio:");
  console.log("  - your chats and their transcripts in ~/.claude");
  console.log("  - your Claude Code login");

  if (!AlsoMcp) {
    console.log("  - the Roblox MCP server, which other Claude apps may use. Pass --mcp to remove it too.");
  }

  console.log("\nLast step, which has to be separate because it deletes this command:");
  console.log("  npm uninstall -g claudio");
}