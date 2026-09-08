import fs from "node:fs";
import path from "node:path";
import { ToolsFolder } from "./Config.js";

const Cache = path.join(ToolsFolder, "api-dump.json");
const Skipped = new Set(["Deprecated", "NotScriptable", "Hidden"]);

let Loaded = null;

function Fresh(Where) {
  try {
    const Age = Date.now() - fs.statSync(Where).mtimeMs;

    return Age < 14 * 24 * 60 * 60 * 1000;
  } catch {
    return false;
  }
}

async function Fetch() {
  const Version = await fetch("https://setup.rbxcdn.com/versionQTStudio").then((Answer) => Answer.text());
  const Dump = await fetch(`https://setup.rbxcdn.com/${Version.trim()}-API-Dump.json`).then((Answer) => Answer.json());

  fs.mkdirSync(path.dirname(Cache), { recursive: true });
  fs.writeFileSync(Cache, JSON.stringify(Dump));

  return Dump;
}

async function Dump() {
  if (Loaded) {
    return Loaded;
  }

  if (Fresh(Cache)) {
    try {
      Loaded = JSON.parse(fs.readFileSync(Cache, "utf8"));

      return Loaded;
    } catch {
      Loaded = null;
    }
  }

  try {
    Loaded = await Fetch();
  } catch {
    try {
      Loaded = JSON.parse(fs.readFileSync(Cache, "utf8"));
    } catch {
      Loaded = null;
    }
  }

  return Loaded;
}

export async function PropertiesFor(ClassName) {
  const Given = await Dump();

  if (!Given || !Given.Classes) {
    return null;
  }

  const ByName = new Map(Given.Classes.map((Entry) => [Entry.Name, Entry]));
  const Names = [];

  let Current = ByName.get(ClassName);

  while (Current) {
    for (const Member of Current.Members || []) {
      if (Member.MemberType !== "Property") {
        continue;
      }

      const Tags = new Set(Member.Tags || []);

      if ([...Tags].some((Tag) => Skipped.has(Tag))) {
        continue;
      }

      const Security = Member.Security;
      const Reads = typeof Security === "string" ? Security : Security && Security.Read;

      if (Reads && Reads !== "None" && Reads !== "PluginSecurity") {
        continue;
      }

      Names.push(Member.Name);
    }

    Current = ByName.get(Current.Superclass);
  }

  return [...new Set(Names)].sort();
}
