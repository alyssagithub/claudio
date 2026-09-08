import fs from "node:fs";
import path from "node:path";
import { AutoTiers, EffortOrder, LeanMode, ModelsCacheFile, ExtraModels } from "./Config.js";

const Trouble = new Map();
const Complaints = /^\s*(no|nope)\b|\b(wrong|incorrect|broken|failing|failed)\b|\bstill (not|no|doesn'?t|does not|broken|failing|wrong|the same)\b|\btry again\b|\b(not|isn'?t) working\b|\b(does|did)n'?t work\b|\bthat'?s not\b|\byou missed\b|\bnothing happened\b|\b(undo|revert) (that|it)\b/i;
const HardWords = /\b(refactor|debug|investigate|why|architecture|design|redesign|rewrite|optimi[sz]e|profile|race|deadlock|memory leak|migrate|plan|audit|review|trace|reproduce)\b/i;
const EditWords = /\b(fix|change|add|remove|rename|move|create|make|write|update|implement|convert|replace|delete|build)\b/i;

const Retired = ["auto-lean", "delegation"];

function WithLeanMode(List) {
  const Kept = List.filter((Model) => Model.value !== LeanMode.value && !Retired.includes(Model.value));

  return [{
    value: LeanMode.value,
    displayName: LeanMode.displayName,
    description: LeanMode.description,
    supportsEffort: false,
    supportedEffortLevels: [],
    contextWindow: 0,
  }].concat(Kept);
}

let Models = WithLeanMode(ReadModelsCache());

function ReadModelsCache() {
  try {
    return JSON.parse(fs.readFileSync(ModelsCacheFile, "utf8"));
  } catch {
    return [];
  }
}

export function GetModels() {
  return WithLeanMode(Models);
}

export function SupportsEffort(Value, Effort) {
  const Model = Models.find((Entry) => Entry.value === Value);

  return Boolean(Effort && Model && Model.supportedEffortLevels.includes(Effort));
}

export function NextEffort(Value, Effort) {
  const Model = Models.find((Entry) => Entry.value === Value);

  if (!Model || !Model.supportsEffort) {
    return null;
  }

  const Levels = EffortOrder.filter((Level) => Model.supportedEffortLevels.includes(Level));
  const Current = Levels.indexOf(Effort || "");

  return Levels[Math.min(Levels.length - 1, Current + 1)] || Levels[Levels.length - 1] || null;
}

export function RememberModels(List) {
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
  }));

  for (const Extra of ExtraModels) {
    if (!Models.some((Model) => Model.value === Extra.value)) {
      Models.push({
        value: Extra.value,
        displayName: Extra.displayName,
        description: Extra.description || "",
        supportsEffort: true,
        supportedEffortLevels: ["low", "medium", "high", "xhigh", "max"],
        contextWindow: Extra.contextWindow,
        extra: true,
      });
    }
  }

  try {
    fs.mkdirSync(path.dirname(ModelsCacheFile), { recursive: true });
    fs.writeFileSync(ModelsCacheFile, JSON.stringify(Models));
  } catch {
    return;
  }
}

export function RecordTurnOutcome(ConversationId, { Failed, Denied }) {
  if (!ConversationId || !(Failed || Denied)) {
    return;
  }

  Trouble.set(ConversationId, Math.min(3, (Trouble.get(ConversationId) || 0) + 1));
}

export function ForgetConversation(ConversationId) {
  Trouble.delete(ConversationId);
}

function Weight(Text, HasContext) {
  const Plain = Text.replace(/<studio_context>[\s\S]*?<\/studio_context>/g, "").trim();
  const Words = Plain.split(/\s+/).length;

  return Math.min(1, Math.min(0.3, Plain.length / 2000)
    + Math.min(0.15, Words / 400)
    + (HardWords.test(Plain) ? 0.32 : 0)
    + (EditWords.test(Plain) ? 0.16 : 0)
    + (HasContext ? 0.12 : 0)
    + (Plain.includes("?") ? 0.05 : 0));
}

export function ChooseModel(ConversationId, Text, HasContext) {
  const Complaining = Complaints.test(Text.slice(0, 200));
  const Previous = Trouble.get(ConversationId) || 0;
  const Escalation = Complaining ? Math.min(3, Previous + 1) : Math.max(0, Previous - 1);

  if (ConversationId) {
    Trouble.set(ConversationId, Escalation);
  }

  return AutoTiers[Math.round(Math.min(1, Weight(Text, HasContext) + Escalation * 0.17) * (AutoTiers.length - 1))];
}