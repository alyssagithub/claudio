import { execFile } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { AnalyzerVersion, DefinitionsUrl, ToolsFolder } from "./Config.js";

const Assets = {
  win32: "luau-lsp-win64.zip",
  darwin: "luau-lsp-macos.zip",
  linux: process.arch === "arm64" ? "luau-lsp-linux-arm64.zip" : "luau-lsp-linux-x86_64.zip",
};

const Ignored = /Unknown require|Unknown type|not found in external type/;

let Ready = null;

function Binary() {
  return path.join(ToolsFolder, process.platform === "win32" ? "luau-lsp.exe" : "luau-lsp");
}

function Definitions() {
  return path.join(ToolsFolder, "globalTypes.d.luau");
}

function Overrides() {
  return path.join(ToolsFolder, "overrides.d.luau");
}

function Run(Command, Args, Options) {
  return new Promise((Resolve) => {
    execFile(Command, Args, { timeout: 30000, maxBuffer: 8 * 1024 * 1024, ...Options }, (Error, Output, Errors) => {
      Resolve({ Failed: Boolean(Error && Error.code === "ENOENT"), Text: `${Output || ""}${Errors || ""}` });
    });
  });
}

async function Download(Url, Into) {
  const Answer = await fetch(Url);

  if (!Answer.ok) {
    throw new Error(`${Answer.status} for ${Url}`);
  }

  fs.writeFileSync(Into, Buffer.from(await Answer.arrayBuffer()));
}

async function OnPath() {
  const Name = process.platform === "win32" ? "luau-lsp.exe" : "luau-lsp";
  const Found = await Run(Name, ["--version"]);

  return !Found.Failed && /\d+\.\d+\.\d+/.test(Found.Text) && !/failed to find|not found|manifest/i.test(Found.Text) ? Name : null;
}

async function Extract(Asset) {
  if (process.platform === "win32") {
    const Shell = await Run("powershell", ["-NoProfile", "-NonInteractive", "-Command", `Expand-Archive -LiteralPath '${Asset}' -DestinationPath '.' -Force`], { cwd: ToolsFolder });

    return Shell.Text;
  }

  const Unzipped = await Run("unzip", ["-o", Asset], { cwd: ToolsFolder });

  if (!Unzipped.Failed) {
    return Unzipped.Text;
  }

  const Tarred = await Run("tar", ["-xf", Asset], { cwd: ToolsFolder });

  return Tarred.Text;
}

async function Install() {
  const Asset = Assets[process.platform];

  if (!Asset) {
    throw new Error(`no luau-lsp build for ${process.platform}`);
  }

  const Archive = path.join(ToolsFolder, Asset);

  fs.mkdirSync(ToolsFolder, { recursive: true });
  await Download(`https://github.com/JohnnyMorganz/luau-lsp/releases/download/${AnalyzerVersion}/${Asset}`, Archive);

  const Extracted = await Extract(Asset);

  fs.rmSync(Archive, { force: true });

  if (!fs.existsSync(Binary())) {
    throw new Error(`extract produced no binary: ${Extracted.slice(0, 200)}`);
  }

  if (process.platform !== "win32") {
    fs.chmodSync(Binary(), 0o755);
  }
}

async function Prepare() {
  const Existing = process.env.CLAUDIO_LUAU_LSP;

  if (!fs.existsSync(Definitions())) {
    fs.mkdirSync(ToolsFolder, { recursive: true });
    await Download(DefinitionsUrl, Definitions());
  }

  if (Existing && fs.existsSync(Existing)) {
    return Existing;
  }

  if (!fs.existsSync(Binary())) {
    const Shared = await OnPath();

    if (Shared) {
      return Shared;
    }

    await Install();
  }

  return Binary();
}

const StudioSettings = "https://clientsettingscdn.roblox.com/v2/settings/application/PCStudioApp";
const Prefixes = ["FFlag", "DFFlag", "FInt", "DFInt", "SFFlag", "FString", "DFString"];

let Tuned = null;

function Published() {
  return path.join(ToolsFolder, "studioflags.json");
}

async function Registry(Analyzer) {
  const Shown = await Run(Analyzer, ["--show-flags"]);

  return Shown.Text
    .split(/\r?\n/)
    .map((Line) => Line.trim().split("=")[0].trim())
    .filter((Name) => Name !== "");
}

async function Settings() {
  const Age = fs.existsSync(Published()) ? Date.now() - fs.statSync(Published()).mtimeMs : Infinity;

  if (Age < 24 * 60 * 60 * 1000) {
    try {
      return JSON.parse(fs.readFileSync(Published(), "utf8"));
    } catch {
      return null;
    }
  }

  const Answer = await fetch(StudioSettings);

  if (!Answer.ok) {
    return null;
  }

  const Body = await Answer.json();
  const Values = Body.applicationSettings || Body;

  fs.mkdirSync(ToolsFolder, { recursive: true });
  fs.writeFileSync(Published(), JSON.stringify(Values));

  return Values;
}

async function Flags(Analyzer) {
  if (Tuned) {
    return Tuned;
  }

  Tuned = process.env.CLAUDIO_NEW_SOLVER === "1" ? ["--flag:LuauSolverV2=True"] : [];

  try {
    const [Names, Values] = await Promise.all([Registry(Analyzer), Settings()]);

    if (!Values) {
      return Tuned;
    }

    for (const Name of Names) {
      if (Name === "LuauSolverV2") {
        continue;
      }

      for (const Prefix of Prefixes) {
        if (Object.hasOwn(Values, Prefix + Name)) {
          Tuned.push(`--flag:${Name}=${Values[Prefix + Name]}`);
          break;
        }
      }
    }
  } catch (Error) {
    console.error(`Could not sync Studio flags: ${Error.message}`);
  }

  return Tuned;
}

const Canary = "__ClaudioCanary";
const Vendored = /(^|[\/])Packages[\/]/;

function Workspace() {
  return path.join(ToolsFolder, "workspace");
}

function SourceMap() {
  return path.join(Workspace(), "sourcemap.json");
}

function FileFor(Where) {
  return Where.split(".").join("/");
}

function Node(Name, Class, Children, Where) {
  const Made = { name: Name, className: Class, filePaths: [] };

  if (Where) {
    Made.filePaths.push(Where);
  }

  if (Children.length > 0) {
    Made.children = Children;
  }

  return Made;
}

function Build(Tree) {
  const Root = { Children: new Map(), Class: "Folder", Source: null };

  for (const Entry of Tree) {
    let At = Root;

    for (const Piece of Entry.path.split(".")) {
      if (!At.Children.has(Piece)) {
        At.Children.set(Piece, { Children: new Map(), Class: "Folder", Source: null });
      }

      At = At.Children.get(Piece);
    }

    At.Class = Entry.className || "ModuleScript";
    At.Source = Entry.source;
  }

  const Written = [];

  function Walk(Name, Holder, Trail) {
    const Children = [...Holder.Children.entries()].map(([Child, Held]) => Walk(Child, Held, `${Trail}.${Child}`));

    if (Holder.Source === null) {
      return Node(Name, "Folder", Children, null);
    }

    const Leaf = Children.length > 0 ? `${FileFor(Trail)}/init.luau` : `${FileFor(Trail)}.luau`;

    Written.push({ File: Leaf, Source: Holder.Source });

    return Node(Name, Holder.Class, Children, Leaf);
  }

  const Top = [...Root.Children.entries()].map(([Child, Held]) => Walk(Child, Held, Child));

  Top.push(Node(Canary, "ModuleScript", [], `${Canary}.luau`));
  Written.push({ File: `${Canary}.luau`, Source: "--!strict\nreturn ClaudioCanaryMissingGlobal\n" });

  return { Map: Node("Root", "DataModel", Top, null), Files: Written };
}

function Lay(Tree) {
  const { Map: Shaped, Files } = Build(Tree);

  fs.rmSync(Workspace(), { recursive: true, force: true });
  fs.mkdirSync(Workspace(), { recursive: true });

  for (const Entry of Files) {
    const Full = path.join(Workspace(), Entry.File);

    fs.mkdirSync(path.dirname(Full), { recursive: true });
    fs.writeFileSync(Full, Entry.Source);
  }

  fs.writeFileSync(SourceMap(), JSON.stringify(Shaped, null, 1));
}

function Parse(Text) {
  const Found = new Map();

  for (const Line of Text.split(/\r?\n/)) {
    const Match = Line.match(/^(.+?\.luau)(?:\s+\[[^\]]*\])?\((\d+),\d+\):\s*(.+)$/);

    if (!Match) {
      continue;
    }

    const Where = path.relative(Workspace(), path.resolve(Workspace(), Match[1])).split(path.sep).join("/");

    if (!Found.has(Where)) {
      Found.set(Where, new Set());
    }

    Found.get(Where).add(`line ${Match[2]}: ${Match[3]}`);
  }

  return Found;
}

export async function Analyze(Entries, Raw, Tree) {
  if (!Ready) {
    Ready = Prepare().catch((Error) => {
      console.error(`Could not prepare the Luau analyzer: ${Error.message}`);
      Ready = null;
      return null;
    });
  }

  const Analyzer = await Ready;

  if (!Analyzer) {
    return null;
  }

  if (Array.isArray(Tree) && Tree.length > 0) {
    Lay(Tree);
  }

  if (!fs.existsSync(SourceMap())) {
    return null;
  }

  const Arguments = ["analyze", ...(await Flags(Analyzer)), `--sourcemap=${SourceMap()}`];

  if (fs.existsSync(Definitions())) {
    Arguments.push(`--definitions=${Definitions()}`);
  }

  if (fs.existsSync(Overrides())) {
    Arguments.push(`--definitions=${Overrides()}`);
  }

  Arguments.push(`${Canary}.luau`);

  for (const Entry of Entries) {
    if (FileFor(Entry.path).includes(Canary)) {
      continue;
    }

    const Nested = path.join(Workspace(), `${FileFor(Entry.path)}/init.luau`);
    const Leaf = fs.existsSync(Nested) ? `${FileFor(Entry.path)}/init.luau` : `${FileFor(Entry.path)}.luau`;
    const Full = path.join(Workspace(), Leaf);

    if (typeof Entry.source === "string" && Entry.source !== "") {
      fs.mkdirSync(path.dirname(Full), { recursive: true });
      fs.writeFileSync(Full, Entry.source);
    }

    Arguments.push(Leaf);
  }

  const Outcome = await Run(Analyzer, Arguments, { cwd: Workspace() });
  const Found = Parse(Outcome.Text);

  if (!Found.has(`${Canary}.luau`)) {
    console.error("The Luau analyzer reported nothing for its canary, so its output cannot be trusted");
    return null;
  }

  Found.delete(`${Canary}.luau`);

  const Report = [];

  for (const [Where, Lines] of Found) {
    if (Vendored.test(Where)) {
      continue;
    }

    const Unique = [...Lines].sort((Left, Right) => Number(Left.match(/\d+/)[0]) - Number(Right.match(/\d+/)[0]));
    const Kept = Raw === true ? Unique : Unique.filter((Line) => !Ignored.test(Line));

    if (Kept.length > 0) {
      Report.push({ path: Where.replace(/\/init\.luau$/, "").replace(/\.luau$/, "").split("/").join("."), lines: Kept.slice(0, 40) });
    }
  }

  return Report;
}

export async function Warm() {
  if (!Ready) {
    Ready = Prepare().catch(() => null);
  }

  const Analyzer = await Ready;

  if (Analyzer) {
    await Flags(Analyzer);
  }
}
