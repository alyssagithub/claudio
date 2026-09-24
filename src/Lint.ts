import { execFile } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { AnalyzerVersion, DefinitionsUrl, ToolsFolder } from "./Config.js";
import type { ScriptEntry, TreeEntry } from "./Types.js";

type Outcome = { Failed: boolean; Stopped: boolean; Text: string };

type TreeItem = TreeEntry & { parts?: string[]; source?: string };

type TreeNode = { name: string; className: string; filePaths: string[]; children?: TreeNode[] };

type Holder = { Children: Map<string, Holder>; Class: string; Source: string | null };

const Assets: Record<string, string> = {
  win32: "luau-lsp-win64.zip",
  darwin: "luau-lsp-macos.zip",
  linux: process.arch === "arm64" ? "luau-lsp-linux-arm64.zip" : "luau-lsp-linux-x86_64.zip",
};

const Ignored = /Key 'Source' not found in external type 'LuaSourceContainer'/;

let Ready: Promise<string | null> | null = null;

function Binary(): string {
  return path.join(ToolsFolder, process.platform === "win32" ? "luau-lsp.exe" : "luau-lsp");
}

function Definitions(): string {
  return path.join(ToolsFolder, "globalTypes.d.luau");
}

function Overrides(): string {
  return path.join(ToolsFolder, "overrides.d.luau");
}

function Run(Command: string, Args: string[], Options?: { cwd?: string }): Promise<Outcome> {
  return new Promise<Outcome>((Resolve) => {
    execFile(Command, Args, { timeout: 30000, maxBuffer: 8 * 1024 * 1024, ...Options }, (Error, Output, Errors) => {
      const Stopped = Error && (Error.killed || Error.signal || Error.code === "ENOBUFS");

      Resolve({
        Failed: Boolean(Error && Error.code === "ENOENT"),
        Stopped: Boolean(Stopped),
        Text: Stopped ? `${Command} did not finish: ${Error.message}` : `${Output || ""}${Errors || ""}`,
      });
    });
  });
}

async function Download(Url: string, Into: string): Promise<void> {
  const Answer = await fetch(Url);

  if (!Answer.ok) {
    throw new Error(`${Answer.status} for ${Url}`);
  }

  fs.writeFileSync(Into, Buffer.from(await Answer.arrayBuffer()));
}

async function OnPath(): Promise<string | null> {
  const Name = process.platform === "win32" ? "luau-lsp.exe" : "luau-lsp";
  const Found = await Run(Name, ["--version"]);

  return !Found.Failed && /\d+\.\d+\.\d+/.test(Found.Text) && !/failed to find|not found|manifest/i.test(Found.Text) ? Name : null;
}

async function Extract(Asset: string): Promise<string> {
  if (process.platform === "win32") {
    const Shell = await Run("powershell", ["-NoProfile", "-NonInteractive", "-Command", `Expand-Archive -LiteralPath '${Asset}' -DestinationPath '.' -Force`], {cwd: ToolsFolder});

    return Shell.Text;
  }

  const Unzipped = await Run("unzip", ["-o", Asset], {cwd: ToolsFolder});

  if (!Unzipped.Failed) {
    return Unzipped.Text;
  }

  const Tarred = await Run("tar", ["-xf", Asset], {cwd: ToolsFolder});

  return Tarred.Text;
}

async function Install(): Promise<void> {
  const Asset = Assets[process.platform];

  if (!Asset) {
    throw new Error(`no luau-lsp build for ${process.platform}`);
  }

  const Archive = path.join(ToolsFolder, Asset);

  fs.mkdirSync(ToolsFolder, {recursive: true});
  await Download(`https://github.com/JohnnyMorganz/luau-lsp/releases/download/${AnalyzerVersion}/${Asset}`, Archive);

  const Extracted = await Extract(Asset);

  fs.rmSync(Archive, {force: true});

  if (!fs.existsSync(Binary())) {
    throw new Error(`Unpacking the Luau analyzer didn't produce a program: ${Extracted.slice(0, 200)}`);
  }

  if (process.platform !== "win32") {
    fs.chmodSync(Binary(), 0o755);
  }

  fs.writeFileSync(InstalledVersion(), AnalyzerVersion);
}

function InstalledVersion(): string {
  return path.join(ToolsFolder, "analyzer-version.txt");
}

async function RefreshDefinitions(): Promise<void> {
  const Age = fs.existsSync(Definitions()) ? Date.now() - fs.statSync(Definitions()).mtimeMs : Infinity;

  if (Age < 24 * 60 * 60 * 1000) {
    return;
  }

  fs.mkdirSync(ToolsFolder, {recursive: true});

  const Fresh = `${Definitions()}.new`;

  try {
    await Download(DefinitionsUrl, Fresh);
    fs.renameSync(Fresh, Definitions());
  } catch (Trouble) {
    fs.rmSync(Fresh, {force: true});

    if (!fs.existsSync(Definitions())) {
      throw Trouble;
    }
  }
}

async function Prepare(): Promise<string> {
  const Existing = process.env.CLAUDIO_LUAU_LSP;

  await RefreshDefinitions();

  if (Existing && fs.existsSync(Existing)) {
    return Existing;
  }

  const Current = fs.existsSync(InstalledVersion()) ? fs.readFileSync(InstalledVersion(), "utf8").trim() : null;

  if (fs.existsSync(Binary()) && Current !== AnalyzerVersion) {
    await Install();
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

let Tuned: Promise<string[]> | null = null;

function Published(): string {
  return path.join(ToolsFolder, "studioflags.json");
}

async function ReadAnalyzerFlags(Analyzer: string): Promise<string[]> {
  const Shown = await Run(Analyzer, ["--show-flags"]);

  return Shown.Text
    .split(/\r?\n/)
    .map((Line) => Line.trim().split("=")[0].trim())
    .filter((Name) => Name !== "");
}

async function Settings(): Promise<Record<string, unknown> | null> {
  const Age = fs.existsSync(Published()) ? Date.now() - fs.statSync(Published()).mtimeMs : Infinity;

  if (Age < 24 * 60 * 60 * 1000) {
    try {
      return JSON.parse(fs.readFileSync(Published(), "utf8")) as Record<string, unknown>;
    } catch {
      return null;
    }
  }

  const Answer = await fetch(StudioSettings);

  if (!Answer.ok) {
    return null;
  }

  const Body = await Answer.json() as Record<string, unknown> & { applicationSettings?: Record<string, unknown> };
  const Values = Body.applicationSettings || Body;

  fs.mkdirSync(ToolsFolder, {recursive: true});
  fs.writeFileSync(Published(), JSON.stringify(Values));

  return Values;
}

function Flags(Analyzer: string): Promise<string[]> {
  Tuned ??= (async () => {
    const Found = process.env.CLAUDIO_NEW_SOLVER === "1" ? ["--flag:LuauSolverV2=True"] : [];

    try {
      const [Names, Values] = await Promise.all([ReadAnalyzerFlags(Analyzer), Settings()]);

      if (!Values) {
        return Found;
      }

      for (const Name of Names) {
        if (Name === "LuauSolverV2") {
          continue;
        }

        for (const Prefix of Prefixes) {
          if (Object.hasOwn(Values, Prefix + Name)) {
            Found.push(`--flag:${Name}=${Values[Prefix + Name]}`);
            break;
          }
        }
      }
    } catch (Error) {
      console.error(`Could not sync Studio flags: ${(Error as NodeJS.ErrnoException).message}`);
    }

    return Found;
  })();

  return Tuned;
}

const Canary = "__ClaudioCanary";

function Workspace(): string {
  return path.join(ToolsFolder, "workspace");
}

function SourceMap(): string {
  return path.join(Workspace(), "sourcemap.json");
}

function FileFor(Where: string): string {
  return Where.split(".").map((Part) => {
    const Safe = Part.replace(/[^a-z0-9-]/gu, (Character) => /^[A-Z]$/.test(Character) ? `^${Character.toLowerCase()}` : `_${Character.codePointAt(0)!.toString(16)}_`);

    return Safe === "" || /^(con|prn|aux|nul|com\d|lpt\d)$/.test(Safe) ? `${Safe}_` : Safe;
  }).join("/");
}

function Node(Name: string, Class: string, Children: TreeNode[], Where: string | null): TreeNode {
  const Made: TreeNode = {
    name: Name,
    className: Class,
    filePaths: [],
  };

  if (Where) {
    Made.filePaths.push(Where);
  }

  if (Children.length > 0) {
    Made.children = Children;
  }

  return Made;
}

function Build(Tree: TreeItem[]) {
  const Root: Holder = {
    Children: new Map(),
    Class: "Folder",
    Source: null,
  };

  for (const Entry of Tree) {
    let At = Root;

    for (const Piece of Array.isArray(Entry.parts) ? Entry.parts : Entry.path.split(".")) {
      if (!At.Children.has(Piece)) {
        At.Children.set(Piece, {
          Children: new Map(),
          Class: "Folder",
          Source: null,
        });
      }

      At = At.Children.get(Piece)!;
    }

    At.Class = Entry.className || "ModuleScript";
    At.Source = typeof Entry.source === "string" ? Entry.source : null;
  }

  const Written: { File: string; Source: string }[] = [];

  function Walk(Name: string, Holder: Holder, Trail: string): TreeNode {
    const Children = [...Holder.Children.entries()].map(([Child, Held]) => Walk(Child, Held, `${Trail}.${Child}`));

    if (Holder.Source === null) {
      return Node(Name, Holder.Class, Children, null);
    }

    const Leaf = Children.length > 0 ? `${FileFor(Trail)}/init.luau` : `${FileFor(Trail)}.luau`;

    Written.push({
      File: Leaf,
      Source: Holder.Source,
    });

    return Node(Name, Holder.Class, Children, Leaf);
  }

  const Top = [...Root.Children.entries()].map(([Child, Held]) => Walk(Child, Held, Child));

  Top.push(Node(Canary, "ModuleScript", [], `${Canary}.luau`));
  Written.push({
    File: `${Canary}.luau`,
    Source: "--!strict\nreturn ClaudioCanaryMissingGlobal\n",
  });

  return {
    Map: Node("Root", "DataModel", Top, null),
    Files: Written,
  };
}

function Lay(Tree: TreeItem[]) {
  const { Map: Shaped, Files } = Build(Tree);

  fs.rmSync(Workspace(), {
    recursive: true,
    force: true,
  });
  fs.mkdirSync(Workspace(), {recursive: true});

  for (const Entry of Files) {
    const Full = path.join(Workspace(), Entry.File);

    fs.mkdirSync(path.dirname(Full), {recursive: true});
    fs.writeFileSync(Full, Entry.Source);
  }

  fs.writeFileSync(SourceMap(), JSON.stringify(Shaped, null, 1));
}

function Parse(Text: string): Map<string, Set<string>> {
  const Found = new Map<string, { Where: string; Parts: string[] }[]>();

  let Open: { Where: string; Parts: string[] } | null = null;

  for (const Line of Text.split(/\r?\n/)) {
    const Match = Line.match(/^(.+?\.luau)(?:\s+\[[^\]]*\])?\((\d+),\d+\):\s*(.+)$/);

    if (!Match) {
      if (Open && Line.trim() !== "") {
        Open.Parts.push(Line.trim());
      } else {
        Open = null;
      }

      continue;
    }

    const Where = path.relative(Workspace(), path.resolve(Workspace(), Match[1])).split(path.sep).join("/");

    if (!Found.has(Where)) {
      Found.set(Where, []);
    }

    Open = {
      Where,
      Parts: [`line ${Match[2]}: ${Match[3]}`],
    };

    Found.get(Where)!.push(Open);
  }

  const Joined = new Map<string, Set<string>>();

  for (const [Where, Entries] of Found) {
    Joined.set(Where, new Set(Entries.map((Entry) => Entry.Parts.join(" "))));
  }

  return Joined;
}

let Queue: Promise<unknown> = Promise.resolve();

export function Analyze(Entries: ScriptEntry[], Raw: boolean, Tree: TreeItem[]) {
  const Run = Queue.then(() => AnalyzeNow(Entries, Raw, Tree));

  Queue = Run.catch(() => {});

  return Run;
}

function Prepared(): Promise<string | null> {
  Ready ??= Prepare().catch((Error) => {
    console.error(`Could not prepare the Luau analyzer: ${Error.message}`);
    Ready = null;
    return null;
  });

  return Ready;
}

async function AnalyzeNow(Entries: ScriptEntry[], Raw: boolean, Tree: TreeItem[]) {
  const Analyzer = await Prepared();

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

  const Leaves: string[] = [];

  for (const Entry of Entries) {
    const File = FileFor(Entry.path);
    const Leaf = fs.existsSync(path.join(Workspace(), `${File}/init.luau`)) ? `${File}/init.luau` : `${File}.luau`;
    const Full = path.join(Workspace(), Leaf);

    if (typeof Entry.source === "string" && Entry.source !== "") {
      fs.mkdirSync(path.dirname(Full), {recursive: true});
      fs.writeFileSync(Full, Entry.source);
    }

    Leaves.push(Leaf);
  }

  const Batches: string[][] = [[]];

  for (const Leaf of Leaves) {
    if (Batches[Batches.length - 1].join(" ").length + Leaf.length > 20000) {
      Batches.push([]);
    }

    Batches[Batches.length - 1].push(Leaf);
  }

  let Text = "";

  for (const Batch of Batches) {
    const Outcome = await Run(Analyzer, Arguments.concat([`${Canary}.luau`], Batch), {cwd: Workspace()});

    if (Outcome.Stopped) {
      console.error(Outcome.Text);
      return null;
    }

    Text += `${Outcome.Text}
`;
  }

  const Found = Parse(Text);

  if (!Found.has(`${Canary}.luau`)) {
    console.error("The Luau analyzer failed its self-check, so script warnings are turned off for now");
    return null;
  }

  Found.delete(`${Canary}.luau`);

  const Report: { path: string; lines: string[] }[] = [];

  for (const [Where, Lines] of Found) {
    const Script = Where.replace(/\/init\.luau$/, "").replace(/\.luau$/, "").split("/").map((Part) => Part.replace(/\^([a-z])|_([0-9a-f]+)_|_$/g, (_, Capital, Code) => {
      if (Capital) {
        return Capital.toUpperCase();
      }

      return Code ? String.fromCodePoint(parseInt(Code, 16)) : "";
    })).join(".");

    if (/(^|\.)Packages\./.test(Script)) {
      continue;
    }

    const Unique = [...Lines].sort((Left, Right) => Number(Left.match(/\d+/)![0]) - Number(Right.match(/\d+/)![0]));
    const Kept = Raw === true ? Unique : Unique.filter((Line) => !Ignored.test(Line));

    if (Kept.length > 0) {
      Report.push({
        path: Script,
        lines: Kept.slice(0, 40),
      });
    }
  }

  return Report;
}

export async function Warm(): Promise<void> {
  const Analyzer = await Prepared();

  if (Analyzer) {
    await Flags(Analyzer);
  }
}