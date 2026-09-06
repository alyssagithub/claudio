import os from "node:os";
import path from "node:path";

export const Version = "1.0.0";
export const ProtocolVersion = 1;
export const DefaultPort = 47225;
export const LongPollMilliseconds = 10000;
export const CoalesceMilliseconds = 120;
export const FinishedTurnLifetimeMilliseconds = 10 * 60 * 1000;
export const GitHubRepo = "alyssagithub/claudio";
export const PluginFileName = "Claudio.rbxm";
export const WorkingDirectory = process.env.CLAUDIO_CWD || os.homedir();
export const DesktopConfigPath = (() => {
  if (process.platform === "darwin") {
    return path.join(os.homedir(), "Library", "Application Support", "Claude", "claude_desktop_config.json");
  }

  if (process.platform !== "win32") {
    return path.join(os.homedir(), ".config", "Claude", "claude_desktop_config.json");
  }

  return path.join(process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming"), "Claude", "claude_desktop_config.json");
})();
export const AllowedTools = [
  "mcp__robloxstudio-mcp__*",
  "mcp__Roblox_Studio__*",
  "mcp__roblox-docs__*",
  "ToolSearch",
  "Skill",
  "Read",
  "Glob",
  "Grep",
  "WebSearch",
  "WebFetch",
];
export function SystemPromptFor(ServerNames) {
  const Lines = ["You are Claudio, a chat assistant in a plugin widget docked in Roblox Studio."];

  if (ServerNames.length === 0) {
    Lines.push("No Roblox tool server is connected, so you cannot read or change the open place. Say that plainly instead of guessing at what the place contains, and tell the user to add one in the Claude desktop app's settings.");
  } else {
    Lines.push(`Read and change the open place with these connected tool servers: ${ServerNames.join(", ")}.`);
  }

  Lines.push(
    "Newer Roblox/Luau you may not know:",
    "`const` declares an immutable local (`const Rate = 5`, `const function Step() end`); reassignment is a compile error.",
    "Instance:QueryDescendants(selector) takes CSS-like selectors, including :not(), :has(), [$AttributeExists], and enum values as strings.",
    "pcall/xpcall no longer use C stack; recursion depth ~20,000, not ~200.",
    "math.tau, math.nan, math.e, math.phi, math.sqrt2, math.isnan, math.isinf, math.isfinite.",
    "EncodingService: Base64, Blake/MD5/SHA hashes, zstd.",
    "UIShadow: GuiObject shadow instance, has Enabled.",
    "Chrono (parihsz/Chrono on wally) takes over character and NPC replication. chrono.Start() on the server and the client is the whole setup, and each model picks NATIVE, NATIVE_WITH_LOCK or CUSTOM. Roblox sends at 20Hz with an interpolation delay you cannot change; Chrono lets you set and read it, keeps a snapshot history so a rewind lands where the player really was, and uses less bandwidth per entity. Its modules are Entity, Holder, Event, Snapshots, ReplicationRules, Stats, Receiver, ServerClock and EntityGrid. Signatures are at parihsz.github.io/Chrono.",
    "Keep replies short. The widget renders headings, bold, italics, bullet lists, inline code, fenced code blocks, and instance paths as clickable links.",
  );

  return Lines.join(" ");
}
export const ModelPrices = {
  opus: { input: 5, output: 25 },
  sonnet: { input: 2, output: 10 },
  haiku: { input: 1, output: 5 },
};
export function PriceFor(Model) {
  const Family = Object.keys(ModelPrices).find((Name) => String(Model).includes(Name));

  return Family ? ModelPrices[Family] : null;
}
export const ExtraModels = [
  { value: "claude-fable-5", displayName: "Fable 5", contextWindow: 1000000, description: "Earlier Fable release · 1M context" },
  { value: "claude-opus-4-8", displayName: "Opus 4.8", contextWindow: 1000000, description: "Earlier Opus release · 1M context" },
  { value: "claude-opus-4-7", displayName: "Opus 4.7", contextWindow: 1000000, description: "Earlier Opus release · 1M context" },
  { value: "claude-opus-4-6", displayName: "Opus 4.6", contextWindow: 200000, description: "Earlier Opus release · 200k context" },
  { value: "claude-sonnet-4-6", displayName: "Sonnet 4.6", contextWindow: 200000, description: "Earlier Sonnet release · 200k context" },
];
export const SessionsRoot = path.join(os.homedir(), ".claude", "projects");
export const DesktopSessionsRoot = path.join(process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming"), "Claude", "claude-code-sessions");
export const OwnSessionsFile = path.join(os.homedir(), ".claudio", "sessions.json");
export const LogFile = path.join(os.homedir(), ".claudio", "bridge.log");
export const MaxImageWidth = 480;
export const ChaptersFile = path.join(os.homedir(), ".claudio", "chapters.json");
export const CostsFile = path.join(os.homedir(), ".claudio", "costs.json");
export const CommandsCacheFile = path.join(os.homedir(), ".claudio", "commands.json");
export const MaxBodyBytes = 12 * 1024 * 1024;
export const KeepSessionsWarm = process.env.CLAUDIO_COLD !== "1";
export const IdleSessionMilliseconds = 4 * 60 * 1000;
export const MaxWarmSessions = 2;
export const ModelsCacheFile = path.join(os.homedir(), ".claudio", "models.json");
export const AutoTiers = [
  { model: "haiku", effort: null },
  { model: "sonnet", effort: "medium" },
  { model: "default", effort: "medium" },
  { model: "default", effort: "high" },
  { model: "default", effort: "max" },
];
export const CancelGraceMilliseconds = 5000;
export const EffortOrder = ["none", "low", "medium", "high", "xhigh", "max"];
