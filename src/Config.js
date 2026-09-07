import os from "node:os";
import path from "node:path";

export const Version = "1.2.0";
export const ProtocolVersion = 1;
export const DefaultPort = 47225;
export const AunId = "264787011452403712";
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
  "Agent",
  "mcp__claudio__*",
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
export const CappedTools = ["Read", "Glob", "Grep"];
export function SystemPromptFor(ServerNames, Delegating) {
  const Lines = ["You are Claudio, a chat assistant in a plugin widget docked in Roblox Studio."];

  if (ServerNames.length === 0) {
    Lines.push("No Roblox tool server is connected, so you cannot read or change the open place. Say that plainly instead of guessing at what the place contains, and tell the user to add one in the Claude desktop app's settings.");
  } else {
    Lines.push(`Read and change the open place with these connected tool servers: ${ServerNames.join(", ")}.`);
  }

  if (Delegating) {
    Lines.push(
      "Reading is delegated here. Count what the question needs before you touch a tool: if it needs more than one script, or the contents of a folder, or a search across the place, your first action is a single Agent call to the reader subagent describing everything you want at once, and it answers with a summary plus the paths and line numbers.",
      "Never walk through several scripts yourself one call at a time; that is the mistake this mode exists to stop.",
      "Read directly only when the question is about one named script, or when you are about to change a script and need its exact current text.",
    );
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
  );

  Lines.push(
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
export const ToolsFolder = path.join(os.homedir(), ".claudio", "tools");
export const AnalyzerVersion = "1.69.0";
export const DefinitionsUrl = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau";
export const LeanMode = {
  value: "token-saver",
  displayName: "Token Saver (Experimental)",
  description: "Auto tiering, delegated bulk reading, and oversized tool results truncated",
};
export const Modes = [
  {
    value: "auto",
    label: "Auto",
    detail: "Claude handles permission decisions",
  },
  {
    value: "default",
    label: "Manual",
    detail: "Always ask before making changes",
  },
  {
    value: "acceptEdits",
    label: "Accept edits",
    detail: "Automatically accept all place edits",
  },
  {
    value: "plan",
    label: "Plan",
    detail: "Create a plan before making changes",
  },
];
export const DefaultMode = "auto";
export function PermissionModeFor(Mode, Bypass) {
  if (Bypass === true) {
    return "bypassPermissions";
  }

  return Modes.some((Entry) => Entry.value === Mode) ? Mode : DefaultMode;
}
export const PlanInstructions = [
  "You are planning work on an open Roblox Studio place. Nothing you do in this phase may change the place.",
  "Read the place first with the Roblox tools: search_objects, get_project_structure, grep_scripts and get_script_source are all read-only and safe.",
  "Then write a numbered plan. Each step names the instance path it touches and what changes there.",
  "Call out anything irreversible on its own line: destroying instances, rewriting a whole script, publishing, or changing Workspace properties.",
  "Say plainly which steps you cannot verify without a playtest.",
  "Keep the plan short enough to read in one go. Do not write the code yet.",
].join(" ");
export const DelegateModels = ["haiku", "sonnet"];
export const Delegates = {
  reader: {
    description: "Reads Roblox instances, scripts and logs in bulk and returns a short summary. Use whenever a read would return more than a screen of text.",
    tools: ["mcp__robloxstudio-mcp__*", "mcp__Roblox_Studio__*", "Read", "Glob", "Grep"],
    prompt: [
      "You read Roblox Studio state and report back compactly.",
      "Answer only what was asked. Quote instance paths and line numbers so the caller can look at the real thing.",
      "Never change anything. Never guess: if the answer is not in what you read, say so.",
      "Prefer twenty accurate lines over two hundred vague ones.",
    ].join(" "),
  },
};
const ConfiguredResultCap = Number(process.env.CLAUDIO_RESULT_CAP);
export const ResultCapCharacters = process.env.CLAUDIO_RESULT_CAP && Number.isFinite(ConfiguredResultCap) && ConfiguredResultCap >= 0 ? ConfiguredResultCap : 16000;
export const ChaptersFile = path.join(os.homedir(), ".claudio", "chapters.json");
export const CostsFile = path.join(os.homedir(), ".claudio", "costs.json");
export const InstalledPluginFile = path.join(os.homedir(), ".claudio", "plugin.json");
export const TokenFile = path.join(os.homedir(), ".claudio", "token.json");
export const CommandsCacheFile = path.join(os.homedir(), ".claudio", "commands.json");
export const MaxBodyBytes = 12 * 1024 * 1024;
export const KeepSessionsWarm = process.env.CLAUDIO_COLD !== "1";
export const IdleSessionMilliseconds = 4 * 60 * 1000;
export const MaxWarmSessions = 2;
export const ModelsCacheFile = path.join(os.homedir(), ".claudio", "models.json");
export const AutoTiers = [
  { model: "haiku", effort: null, delegate: "haiku" },
  { model: "sonnet", effort: "none", delegate: "haiku" },
  { model: "sonnet", effort: "low", delegate: "haiku" },
  { model: "sonnet", effort: "medium", delegate: "haiku" },
  { model: "sonnet", effort: "high", delegate: "haiku" },
  { model: "sonnet", effort: "xhigh", delegate: "haiku" },
  { model: "sonnet", effort: "max", delegate: "haiku" },
  { model: "default", effort: "none", delegate: "haiku" },
  { model: "default", effort: "low", delegate: "haiku" },
  { model: "default", effort: "medium", delegate: "haiku" },
  { model: "default", effort: "high", delegate: "haiku" },
  { model: "default", effort: "xhigh", delegate: "sonnet" },
  { model: "default", effort: "max", delegate: "sonnet" },
];
export const CancelGraceMilliseconds = 5000;
export const EffortOrder = ["none", "low", "medium", "high", "xhigh", "max"];
