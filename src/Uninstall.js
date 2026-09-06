import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { DefaultPort, DesktopConfigPath, PluginFileName } from "./Config.js";
import { GetPluginsFolder } from "./StudioPaths.js";
import { StopBridge, UninstallStartup } from "./Startup.js";

function Remove(Target, Label, Removed, Kept) {
  if (!fs.existsSync(Target)) {
    Kept.push(`${Label} was not there`);
    return;
  }

  try {
    fs.rmSync(Target, { recursive: true, force: true });
    Removed.push(`${Label} (${Target})`);
  } catch (Error) {
    Kept.push(`${Label} could not be removed: ${Error.message}`);
  }
}

function DropMcpServer(Removed, Kept) {
  let Config = null;

  try {
    Config = JSON.parse(fs.readFileSync(DesktopConfigPath, "utf8"));
  } catch {
    Kept.push("the Claude desktop config was not readable, so its MCP servers were left alone");
    return;
  }

  if (!Config.mcpServers || !Config.mcpServers["robloxstudio-mcp"]) {
    Kept.push("no robloxstudio-mcp entry to remove");
    return;
  }

  delete Config.mcpServers["robloxstudio-mcp"];
  fs.writeFileSync(DesktopConfigPath, JSON.stringify(Config, null, 2));
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
        await fetch(`http://127.0.0.1:${Port}/health`);
      } catch {
        break;
      }
    }
  }

  try {
    UninstallStartup();
  } catch (Error) {
    Kept.push(`the startup launcher could not be removed: ${Error.message}`);
  }

  Remove(path.join(GetPluginsFolder(), PluginFileName), "the Studio plugin", Removed, Kept);
  Remove(path.join(os.homedir(), ".claudio"), "Claudio's own folder", Removed, Kept);
  Remove(`${DesktopConfigPath}.claudio-backup`, "the config backup Claudio made", Removed, Kept);

  if (AlsoMcp) {
    DropMcpServer(Removed, Kept);
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
