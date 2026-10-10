import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { ModelsCacheFile } from "./Config.js";

type ModelEntry = {
  value: string;
  displayName: string;
  description: string;
  supportsEffort: boolean;
  supportedEffortLevels: string[];
  contextWindow: number;
  extra?: boolean;
  supportsFastMode?: boolean;
};

const Retired = ["auto-lean", "delegation", "default", "token-saver"];

function WithoutRetired(List: ModelEntry[]): ModelEntry[] {
  return List.filter((Model) => !Retired.includes(Model.value));
}

let Models = WithoutRetired(ReadModelsCache());

function ReadModelsCache(): ModelEntry[] {
  try {
    return JSON.parse(fs.readFileSync(ModelsCacheFile, "utf8")) as ModelEntry[];
  } catch {
    return [];
  }
}

export function GetModels() {
  return WithoutRetired(Models);
}

export function SupportsFastMode(Value: string | undefined): boolean {
  const Model = Models.find((Entry) => Entry.value === Value);

  return !Model || Model.supportsFastMode === true;
}

export function SupportsEffort(Value: string, Effort: string | null | undefined): boolean {
  const Model = Models.find((Entry) => Entry.value === Value);

  return Boolean(Effort && Model && Model.supportedEffortLevels.includes(Effort));
}

type Released = ModelEntry & { line: string; latest: boolean };

const ReleasedFile = path.join(path.dirname(ModelsCacheFile), "released-models.json");
const SdkFile = path.join(path.dirname(ModelsCacheFile), "sdk-models.json");
let Sdk: ModelEntry[] = ReadJsonList(SdkFile);
let Listed: Released[] = ReadJsonList(ReleasedFile);

function ReadJsonList<Entry>(File: string): Entry[] {
  try {
    return JSON.parse(fs.readFileSync(File, "utf8")) as Entry[];
  } catch {
    return [];
  }
}

function Merge() {
  if (Sdk.length === 0) {
    return;
  }

  Models = Sdk.filter((Model, Index) => Sdk.findIndex((Other) => Other.displayName === Model.displayName) === Index).map((Model) => ({...Model}));

  for (const Release of Listed) {
    const Known = Models.find((Model) => Model.value === Release.value || Model.value === Release.value.replace(/\[1m\]$/, "") || Model.displayName === Release.displayName);

    if (Known && Known.description === "Custom model") {
      Known.displayName = Release.displayName;
      Known.description = Release.description;
      Known.contextWindow = Release.contextWindow;
    }

    if (!Known) {
      Models.push({...Release, line: undefined, latest: undefined, extra: true} as ModelEntry);
    }
  }

  for (const Release of Listed.filter((Entry) => Entry.latest)) {
    const Alias = Models.find((Model) => Model.value === Release.line);
    const Entry = Models.find((Model) => Model.value === Release.value);

    if (!Alias || !Entry || Alias.displayName === Release.displayName || String(Alias.description).startsWith(Release.displayName)) {
      continue;
    }

    Models.splice(Models.indexOf(Entry), 1);
    Models.splice(Models.indexOf(Alias), 0, {...Entry, extra: undefined});
    Alias.extra = true;
  }

  const Families = new Set<string>();

  for (const Model of Models) {
    const Family = (Model.displayName.match(/^[A-Za-z]+/) || [Model.value])[0].toLowerCase();

    Model.extra = Families.has(Family) ? true : undefined;
    Families.add(Family);
  }

  try {
    fs.mkdirSync(path.dirname(ModelsCacheFile), {recursive: true});
    fs.writeFileSync(ModelsCacheFile, JSON.stringify(Models));
  } catch {
    return;
  }
}

export function RememberModels(List: unknown): void {
  if (!Array.isArray(List) || List.length === 0) {
    return;
  }

  Sdk = List.map((Model) => ({
    value: Model.value,
    displayName: Model.displayName,
    description: Model.description,
    supportsEffort: Boolean(Model.supportsEffort),
    supportedEffortLevels: Model.supportedEffortLevels || [],
    contextWindow: Model.contextWindow || 0,
    supportsFastMode: Model.supportsFastMode === true,
  }));

  try {
    fs.mkdirSync(path.dirname(SdkFile), {recursive: true});
    fs.writeFileSync(SdkFile, JSON.stringify(Sdk));
  } catch {
    return;
  } finally {
    Merge();
  }
}

export function ReloadReleased() {
  Listed = ReadJsonList(ReleasedFile);
  Merge();
}

export async function RefreshReleased(): Promise<void> {
  let Token: string | undefined;

  try {
    Token = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude", ".credentials.json"), "utf8")).claudeAiOauth?.accessToken;
  } catch {
    return;
  }

  if (!Token) {
    return;
  }

  try {
    const Response = await fetch("https://api.anthropic.com/v1/models?limit=100", {
      headers: {
        Authorization: `Bearer ${Token}`,
        "anthropic-version": "2023-06-01",
        "anthropic-beta": "oauth-2025-04-20",
      },
      signal: AbortSignal.timeout(20000),
    });

    if (!Response.ok) {
      console.error(`Could not list Claude models: ${Response.status} ${Response.statusText}`);
      return;
    }

    const Seen = new Set<string>();
    const Data = ((await Response.json()) as { data?: { id: string; display_name: string; line?: string; max_input_tokens?: number; lifecycle?: string; capabilities?: { effort?: Record<string, { supported?: boolean } | boolean> } }[] }).data || [];

    Listed = Data.filter((Model) => Model.lifecycle !== "retired").map((Model) => {
      const Line = Model.line || (Model.id.match(/^claude-([a-z]+)/) || [])[1] || "";
      const Window = Model.max_input_tokens || 200000;
      const Latest = !Seen.has(Line);
      const Effort = Model.capabilities && Model.capabilities.effort;
      const Levels = Effort ? ["low", "medium", "high", "xhigh", "max"].filter((Level) => Effort[Level] && (Effort[Level] as { supported?: boolean }).supported) : [];
      const Name = Model.display_name.replace(/^Claude /, "");

      Seen.add(Line);

      return {
        value: Line === "sonnet" && Window >= 1000000 ? `${Model.id}[1m]` : Model.id,
        displayName: Name,
        description: `${Latest ? "Latest" : "Earlier"} ${Line.charAt(0).toUpperCase()}${Line.slice(1)} release · ${Window >= 1000000 ? `${Window / 1000000}M` : `${Math.round(Window / 1000)}K`} context${Model.lifecycle === "deprecated" ? " · deprecated" : ""}`,
        supportsEffort: Levels.length > 0,
        supportedEffortLevels: Levels,
        contextWindow: Window,
        supportsFastMode: Line === "opus",
        line: Line,
        latest: Latest,
      };
    });

    fs.mkdirSync(path.dirname(ReleasedFile), {recursive: true});
    fs.writeFileSync(ReleasedFile, JSON.stringify(Listed));
    Merge();
  } catch (Trouble) {
    console.error(`Could not list Claude models: ${(Trouble as Error).message}`);
  }
}
