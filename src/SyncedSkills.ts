import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SyncedRoot = path.join(os.homedir(), ".claude", "skills", "synced");
const OwnRoot = path.join(os.homedir(), ".claude", "skills");

export const MirrorFolder = path.join(os.homedir(), ".claudio", "skills");
export const MirrorSkills = path.join(MirrorFolder, ".claude", "skills");

let CheckedAt = 0;
let Mirrored = "";

function Folders(Parent: string): string[] {
  try {
    return fs.readdirSync(Parent, {withFileTypes: true}).filter((Entry) => Entry.isDirectory()).map((Entry) => Entry.name);
  } catch {
    return [];
  }
}

function Newest(Folder: string): number {
  let Latest = 0;

  for (const Entry of fs.readdirSync(Folder, {withFileTypes: true})) {
    const Full = path.join(Folder, Entry.name);

    Latest = Math.max(Latest, fs.statSync(Full).mtimeMs, Entry.isDirectory() ? Newest(Full) : 0);
  }

  return Latest;
}

export function MirrorSyncedSkills(): string {
  if (Date.now() - CheckedAt < 30000) {
    return MirrorFolder;
  }

  CheckedAt = Date.now();

  try {
    const Found = new Map<string, string>();

    for (const Bucket of Folders(SyncedRoot)) {
      for (const Name of Folders(path.join(SyncedRoot, Bucket))) {
        const From = path.join(SyncedRoot, Bucket, Name);

        if (fs.existsSync(path.join(From, "SKILL.md")) && !fs.existsSync(path.join(OwnRoot, Name, "SKILL.md"))) {
          Found.set(Name, From);
        }
      }
    }

    const Signature = [...Found].map(([Name, From]) => `${Name}:${Newest(From)}`).join("|");

    if (Signature === Mirrored && fs.existsSync(MirrorSkills)) {
      return MirrorFolder;
    }

    fs.rmSync(MirrorSkills, {recursive: true, force: true});
    fs.mkdirSync(MirrorSkills, {recursive: true});

    for (const [Name, From] of Found) {
      fs.cpSync(From, path.join(MirrorSkills, Name), {recursive: true});
    }

    Mirrored = Signature;
  } catch (Trouble) {
    console.error(`Could not copy your claude.ai skills for Claudio: ${(Trouble as Error).message}`);
  }

  return MirrorFolder;
}