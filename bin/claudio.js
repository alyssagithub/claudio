#!/usr/bin/env node
import { DefaultPort } from "../src/Config.js";
import { InstallPlugin } from "../src/PluginInstaller.js";
import { StartServer } from "../src/Server.js";
import { RunSetup } from "../src/Setup.js";
import { RunUninstall } from "../src/Uninstall.js";
import { ReportVersion } from "../src/Version.js";
import { InstallStartup, RestartBridge, StopBridge, UninstallStartup } from "../src/Startup.js";

const Arguments = process.argv.slice(2);
const Command = Arguments[0];

function ReadFlag(Name) {
  const Index = Arguments.indexOf(Name);

  return Index === -1 ? null : Arguments[Index + 1];
}

function Fail(Error) {
  console.error(Error.message);
  process.exit(1);
}

if (Command === "setup") {
  RunSetup(ReadFlag("--local")).catch(Fail);
} else if (Command === "uninstall") {
  RunUninstall(Arguments.includes("--mcp")).catch(Fail);
} else if (Command === "install") {
  InstallPlugin(ReadFlag("--local")).catch(Fail);
} else if (Command === "install-startup") {
  try {
    InstallStartup().catch(Fail);
  } catch (Error) {
    Fail(Error);
  }
} else if (Command === "version" || Arguments.includes("--version")) {
  ReportVersion().catch(Fail);
} else if (Command === "uninstall-startup") {
  UninstallStartup();
} else if (Command === "restart") {
  RestartBridge(Number(ReadFlag("--port") || process.env.CLAUDIO_PORT || DefaultPort)).catch(Fail);
} else if (Command === "stop") {
  StopBridge(Number(ReadFlag("--port") || process.env.CLAUDIO_PORT || DefaultPort));
} else if (Command === undefined || Command === "start") {
  StartServer(Number(ReadFlag("--port") || process.env.CLAUDIO_PORT || DefaultPort));
} else {
  console.error("Usage: claudio setup | claudio uninstall [--mcp] | claudio [start] [--port N] | claudio install [--local path/to/Claudio.rbxm] | claudio install-startup | claudio uninstall-startup | claudio restart | claudio stop | claudio version");
  process.exit(1);
}
