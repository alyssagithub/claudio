import fs from "node:fs";
import path from "node:path";
import { exec, spawn } from "node:child_process";
import { AllowedTools, DesktopConfigPath } from "./Config.js";
import { InstallPlugin } from "./PluginInstaller.js";
import { GetPluginsFolder } from "./StudioPaths.js";
import { InstallStartup } from "./Startup.js";

const RobloxServer = {
  command: process.platform === "win32" ? "cmd" : "npx",
  args: process.platform === "win32"
    ? ["/c", "npx", "-y", "@chrrxs/robloxstudio-mcp@latest", "--auto-install-plugin"]
    : ["-y", "@chrrxs/robloxstudio-mcp@latest", "--auto-install-plugin"],
};

function Run(Line) {
  return new Promise((Resolve) => {
    exec(Line, { timeout: 300000 }, (Error, Stdout, Stderr) => {
      Resolve({ Ok: !Error, Output: `${Stdout || ""}${Stderr || ""}`.trim() });
    });
  });
}

function ReadConfig() {
  try {
    return JSON.parse(fs.readFileSync(DesktopConfigPath, "utf8"));
  } catch {
    return null;
  }
}

const Usable = AllowedTools
  .filter((Name) => Name.startsWith("mcp__"))
  .map((Name) => Name.split("__")[1]);

function HasRobloxServer(Config) {
  return Object.keys((Config && Config.mcpServers) || {}).some((Name) => Usable.includes(Name));
}

// A fresh npm install of Claude Code is not on this process's PATH yet, so
// point the new window at the shim directly when it is there. The login
// window has to own its console outright: exec hands the child this
// process's pipes, and the prompt then draws on screen while the typing
// goes into a pipe nobody reads.
function OpenLoginWindow() {
  const Shim = path.join(process.env.APPDATA || "", "npm", "claude.cmd");
  const Command = fs.existsSync(Shim) ? Shim : "claude";

  try {
    const Window = spawn("cmd", ["/c", "start", "Claude Code login", "cmd", "/k", Command, "auth", "login"], {
      detached: true,
      stdio: "ignore",
      windowsHide: false,
    });

    Window.unref();

    return true;
  } catch {
    return false;
  }
}

async function EnsureClaude(Manual) {
  const Found = await Run("claude --version");

  if (Found.Ok) {
    console.log(`Found Claude Code ${Found.Output.split("\n")[0].replace(" (Claude Code)", "")}.`);
  } else {
    console.log("No Claude Code, installing it. Takes a minute.");

    const Installed = await Run("npm install -g @anthropic-ai/claude-code");

    if (!Installed.Ok) {
      Manual.push("Install Claude Code yourself: npm install -g @anthropic-ai/claude-code");
      return;
    }

    console.log("Done.");
  }

  const Status = await Run("claude auth status");

  if (Status.Ok && /true|logged in/i.test(Status.Output)) {
    console.log("Logged in already.");
    return;
  }

  if (process.platform === "win32" && OpenLoginWindow()) {
    console.log("Opened a window to log in to Claude Code. Sign in there, the rest of this carries on meanwhile.");
    Manual.push("Finish the Claude Code login in the window that opened. Claudio uses that login, there is no API key to paste.");
    return;
  }

  Manual.push("Log in to Claude Code: run `claude` in a terminal, then follow the browser prompt. Claudio uses that login, so there is no API key to paste.");
}

function EnsureRobloxServer(Manual) {
  const Config = ReadConfig();

  if (HasRobloxServer(Config)) {
    console.log("Roblox MCP server already configured.");
    return;
  }

  const Fresh = Config || {};

  if (Config) {
    fs.copyFileSync(DesktopConfigPath, `${DesktopConfigPath}.claudio-backup`);
  } else {
    fs.mkdirSync(path.dirname(DesktopConfigPath), { recursive: true });
  }

  Fresh.mcpServers = Fresh.mcpServers || {};
  Fresh.mcpServers["robloxstudio-mcp"] = RobloxServer;
  fs.writeFileSync(DesktopConfigPath, JSON.stringify(Fresh, null, 2));

  console.log(Config ? "Added robloxstudio-mcp to the Claude desktop config (previous file kept as .claudio-backup)." : `Created ${DesktopConfigPath} with robloxstudio-mcp.`);
  Manual.push("Fully close and reopen Roblox Studio so the Roblox MCP plugin loads, then check it shows Connected.");
}

export async function RunSetup(LocalPath) {
  const Manual = [];

  console.log("Setting up.\n");

  await EnsureClaude(Manual);

  try {
    await InstallPlugin(LocalPath);
  } catch (Error) {
    Manual.push(`Install the plugin yourself: download Claudio.rbxm from the releases page and drop it in ${GetPluginsFolder()}`);
    console.log(`Could not install the plugin automatically: ${Error.message}`);
  }

  EnsureRobloxServer(Manual);

  if (process.platform === "win32") {
    try {
      await InstallStartup();
    } catch (Error) {
      Manual.push("Start the bridge by running `claudio` and leaving that window open (" + Error.message + ")");
    }
  } else {
    Manual.push("Start the bridge by running `claudio` and leaving that window open. Starting it automatically is Windows-only so far.");
  }

  Manual.push("Restart Roblox Studio, then open the Claudio button in the Plugins tab.");

  console.log("\nLeft for you:\n");

  for (const [Index, Step] of Manual.entries()) {
    console.log(`  ${Index + 1}. ${Step}`);
  }

  console.log("\nThe bridge is up. From here Studio is the only thing you need to open.");
}