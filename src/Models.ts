import fs from "node:fs";
import path from "node:path";
import { ModelsCacheFile, ExtraModels } from "./Config.js";

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

export function RememberModels(List: unknown): void {
  if (!Array.isArray(List) || List.length === 0) {
    return;
  }

  Models = List.map((Model) => ({
    value: Model.value,
    displayName: Model.displayName,
    description: Model.description,
    supportsEffort: Boolean(Model.supportsEffort),
    supportedEffortLevels: Model.supportedEffortLevels || [],
    contextWindow: Model.contextWindow || 0,
    supportsFastMode: Model.supportsFastMode === true,
  }));

  for (const Extra of ExtraModels) {
    const Listed = Models.find((Model) => Model.value === Extra.value);

    if (Listed && Listed.description === "Custom model") {
      Listed.displayName = Extra.displayName;
      Listed.description = Extra.description || "";
      Listed.contextWindow = Extra.contextWindow;
    }

    if (!Listed) {
      Models.push({
        value: Extra.value,
        displayName: Extra.displayName,
        description: Extra.description || "",
        supportsEffort: true,
        supportedEffortLevels: ["low", "medium", "high", "xhigh", "max"],
        contextWindow: Extra.contextWindow,
        supportsFastMode: Extra.fast === true,
        extra: true,
      });
    }
  }

  for (const Newer of ExtraModels) {
    const Older = Models.find((Model) => Model.value === Newer.replaces);
    const Entry = Models.find((Model) => Model.value === Newer.value);

    if (!Older || !Entry || String(Older.description).startsWith(Newer.displayName)) {
      continue;
    }

    Models.splice(Models.indexOf(Entry), 1);
    Models.splice(Models.indexOf(Older), 0, {...Entry, extra: undefined});
    Older.extra = true;
  }

  try {
    fs.mkdirSync(path.dirname(ModelsCacheFile), {recursive: true});
    fs.writeFileSync(ModelsCacheFile, JSON.stringify(Models));
  } catch {
    return;
  }
}
