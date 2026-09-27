import fs from "node:fs";
import path from "node:path";

export type DiskNode = {
  name: string;
  class: string;
  source?: string;
  value?: string;
  rbxm?: string;
  properties?: Record<string, unknown>;
  attributes?: Record<string, unknown>;
  children: DiskNode[];
};

const Scripts: [RegExp, string][] = [
  [/^(.+)\.server\.luau?$/, "Script"],
  [/^(.+)\.legacy\.luau?$/, "Script"],
  [/^(.+)\.client\.luau?$/, "LocalScript"],
  [/^(.+)\.local\.luau?$/, "LocalScript"],
  [/^(.+)\.luau?$/, "ModuleScript"],
];

function ReadMeta(File: string): {className?: string, properties?: Record<string, unknown>, attributes?: Record<string, unknown>} {
  if (!fs.existsSync(File)) {
    return {};
  }

  const Parsed = JSON.parse(fs.readFileSync(File, "utf8").replace(/^﻿/, "")) as Record<string, unknown>;

  return {
    className: typeof Parsed.className === "string" ? Parsed.className : undefined,
    properties: Parsed.properties && typeof Parsed.properties === "object" ? Parsed.properties as Record<string, unknown> : undefined,
    attributes: Parsed.attributes && typeof Parsed.attributes === "object" ? Parsed.attributes as Record<string, unknown> : undefined,
  };
}

function Dress(Node: DiskNode, Meta: ReturnType<typeof ReadMeta>): DiskNode {
  return {
    ...Node,
    class: Meta.className || Node.class,
    ...(Meta.properties ? {properties: Meta.properties} : {}),
    ...(Meta.attributes ? {attributes: Meta.attributes} : {}),
  };
}

function Read(Text: string): string {
  return Text.replace(/\r\n/g, "\n");
}

export function ReadDiskTree(Folder: string, Name: string): DiskNode {
  const Entries = fs.readdirSync(Folder, {withFileTypes: true}).sort((Left, Right) => Left.name.localeCompare(Right.name));
  const Init = Entries.find((Entry) => Entry.isFile() && /^init(\.server|\.client|\.local|\.legacy)?\.luau?$/.test(Entry.name));
  const Class = Init ? Scripts.find(([Pattern]) => Pattern.test(Init.name))![1] : "Folder";

  let Node: DiskNode = {
    name: Name,
    class: Class,
    ...(Init ? {source: Read(fs.readFileSync(path.join(Folder, Init.name), "utf8"))} : {}),
    children: [],
  };

  Node = Dress(Node, ReadMeta(path.join(Folder, "init.meta.json")));

  for (const Entry of Entries) {
    const Full = path.join(Folder, Entry.name);

    if (Entry.isDirectory()) {
      Node.children.push(ReadDiskTree(Full, Entry.name));
      continue;
    }

    if (Entry === Init || Entry.name.endsWith(".meta.json")) {
      continue;
    }

    const Script = Scripts.map(([Pattern, Kind]) => [Entry.name.match(Pattern), Kind] as const).find(([Found]) => Found);

    if (Script && Script[0]) {
      const Base = Script[0][1];

      Node.children.push(Dress({name: Base, class: Script[1], source: Read(fs.readFileSync(Full, "utf8")), children: []}, ReadMeta(path.join(Folder, `${Base}.meta.json`))));
      continue;
    }

    if (Entry.name.endsWith(".txt")) {
      const Base = Entry.name.slice(0, -4);

      Node.children.push(Dress({name: Base, class: "StringValue", value: Read(fs.readFileSync(Full, "utf8")), children: []}, ReadMeta(path.join(Folder, `${Base}.meta.json`))));
      continue;
    }

    if (Entry.name.endsWith(".rbxm")) {
      Node.children.push({name: Entry.name.slice(0, -5), class: "Folder", rbxm: fs.readFileSync(Full).toString("base64"), children: []});
    }
  }

  return Node;
}
