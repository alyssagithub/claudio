import fs from "node:fs";
import path from "node:path";
import { exec, spawn } from "node:child_process";
import { AllowedTools, DesktopConfigPath } from "./Config.js";
import { InstallPlugin } from "./PluginInstaller.js";
import { GetPluginsFolder } from "./StudioPaths.js";
import { InstallStartup } from "./Startup.js";
import { ReadConfig, RobloxServer, WriteConfig } from "./DesktopConfig.js";

function Run(Line) {
  return new Promise((Resolve) => {
    exec(Line, { timeout: 300000 }, (Error, Stdout, Stderr) => {
      Resolve({ Ok: !Error, Output: `${Stdout || ""}${Stderr || ""}`.trim() });
    });
  });
}

const Usable = AllowedTools
  .filter((Name) => Name.startsWith("mcp__"))
  .map((Name) => Name.split("__")[1]);

function HasRobloxServer(Config) {
  return Object.keys((Config && Config.mcpServers) || {}).some((Name) => Usable.includes(Name));
}

async function EnsureClaude(Manual) {
  const Found = await Run("claude --version");

  if (Found.Ok) {
    console.log(`Found Claude Code ${Found.Output.split("\n")[0].replace(" (Claude Code)", "")}.`);
  } else {
    console.log("No Claude Code, installing it. Takes a minute.");

    const Installed = await Run("npm install -g @anthropic-ai/claude-code");

    if (!Installed.Ok) {
      Manual.push("Install Claude Code yourself: npm install -g @anthropic-ai/claude-code, then run `claude auth login`.");
      return false;
    }

    console.log("Done.");
  }

  const Status = await Run("claude auth status");

  if (Status.Ok && /true|logged in/i.test(Status.Output)) {
    console.log("Logged in already.");
    return false;
  }

  return true;
}

// Sign in here rather than in a window of our own. A window we open gets a
// console we cannot vouch for, and a sign-in prompt that will not take
// keystrokes is indistinguishable from a hung install; this terminal is one
// the person is already typing in.
function SignIn() {
  return new Promise((Resolve) => {
    if (!process.stdin.isTTY) {
      Resolve(false);
      return;
    }

    console.log("\nSigning in to Claude Code. A browser opens, and the code comes back here.\n");

    const Login = spawn(process.platform === "win32" ? "claude.cmd" : "claude", ["auth", "login"], {
      stdio: "inherit",
      shell: process.platform === "win32",
    });

    Login.on("error", () => Resolve(false));
    Login.on("close", (Code) => Resolve(Code === 0));
  });
}

function EnsureRobloxServer(Manual) {
  const Read = ReadConfig();

  if (Read.Unreadable) {
    console.log(`Left the Claude desktop config alone, it could not be read: ${Read.Unreadable}`);
    Manual.push(`Add robloxstudio-mcp to ${DesktopConfigPath} yourself. Claudio did not touch it because it could not read it, and overwriting would have lost whatever is in there.`);
    return;
  }

  if (HasRobloxServer(Read.Config)) {
    console.log("Roblox MCP server already configured.");
    return;
  }

  const Fresh = Read.Config || {};

  if (Read.Missing) {
    fs.mkdirSync(path.dirname(DesktopConfigPath), { recursive: true });
  } else {
    fs.copyFileSync(DesktopConfigPath, `${DesktopConfigPath}.claudio-backup`);
  }

  Fresh.mcpServers = Fresh.mcpServers || {};
  Fresh.mcpServers["robloxstudio-mcp"] = RobloxServer;
  WriteConfig(Fresh);

  console.log(Read.Missing ? `Created ${DesktopConfigPath} with robloxstudio-mcp.` : "Added robloxstudio-mcp to the Claude desktop config (previous file kept as .claudio-backup).");
  Manual.push("Fully close and reopen Roblox Studio so the Roblox MCP plugin loads, then check it shows Connected.");
}

export async function RunSetup(LocalPath) {
  const Manual = [];

  console.log("Setting up.\n");

  const NeedsLogin = await EnsureClaude(Manual);

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

  if (NeedsLogin && !(await SignIn())) {
    Manual.unshift("Log in to Claude Code: run `claude auth login` and follow the browser prompt. Claudio uses that login, so there is no API key to paste.");
  }

  console.log("\nLeft for you:\n");

  for (const [Index, Step] of Manual.entries()) {
    console.log(`  ${Index + 1}. ${Step}`);
  }

  console.log("\nThe bridge is up. From here Studio is the only thing you need to open.");
}