import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import { GitHubRepo, PluginFileName } from "./Config.js";
import { GetPluginsFolder } from "./StudioPaths.js";

const InstalledFile = path.join(os.homedir(), ".claudio", "installed.json");

type InstalledRecord = {
  commit: string;
  at: number | string;
};

export type CommitRecord = {
  sha: string;
  commit: {
    message: string;
    committer: {
      date: string;
    };
  };
};

export function Installed(): InstalledRecord | null {
  try {
    const Record = JSON.parse(fs.readFileSync(InstalledFile, "utf8").replace(/^﻿/, "")) as InstalledRecord;

    return typeof Record.commit === "string" && Record.commit !== "" ? Record : null;
  } catch {
    return null;
  }
}

export function IsCheckout(): boolean {
  return fs.existsSync(path.join(path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", ".."), ".git"));
}

export async function LatestCommit(): Promise<CommitRecord> {
  const Response = await fetch(`https://api.github.com/repos/${GitHubRepo}/commits/main`, {
    headers: {
      "User-Agent": "claudio",
      "Cache-Control": "no-cache",
    },
    signal: AbortSignal.timeout(30000),
  });

  if (!Response.ok) {
    throw new Error(`GitHub answered ${Response.status}`);
  }

  return await Response.json() as CommitRecord;
}

function WritePlugin(Body: Buffer): string {
  if (Body.length < 1024 || !Body.subarray(0, 8).toString("binary").startsWith("<roblox")) {
    throw new Error("That download is not a Roblox model file");
  }

  const Folder = GetPluginsFolder();
  const Target = path.join(Folder, PluginFileName);
  const Temporary = `${Target}.claudio-writing`;

  fs.mkdirSync(Folder, {recursive: true});

  try {
    fs.writeFileSync(Temporary, Body);
    fs.renameSync(Temporary, Target);
  } catch (Error) {
    fs.rmSync(Temporary, {force: true});

    throw Error;
  }

  return Target;
}

async function DownloadPlugin(Commit: string): Promise<string> {
  const Response = await fetch(`https://raw.githubusercontent.com/${GitHubRepo}/${Commit}/${PluginFileName}`, {
    headers: {"User-Agent": "claudio"},
    signal: AbortSignal.timeout(120000),
  });

  if (!Response.ok) {
    throw new Error(`Could not download ${PluginFileName} from commit ${Commit.slice(0, 7)} (${Response.status})`);
  }

  return WritePlugin(Buffer.from(await Response.arrayBuffer()));
}

function Remember(Commit: string) {
  fs.mkdirSync(path.dirname(InstalledFile), {recursive: true});
  fs.writeFileSync(InstalledFile, JSON.stringify({commit: Commit, at: new Date().toISOString()}, null, 2));
}

export async function InstallPlugin(LocalPath?: string | null): Promise<void> {
  if (LocalPath) {
    console.log(`Copied ${LocalPath} to ${WritePlugin(fs.readFileSync(LocalPath))}`);

    return;
  }

  const Commit = (Installed() || {commit: (await LatestCommit()).sha}).commit;

  console.log(`Installed ${PluginFileName} from commit ${Commit.slice(0, 7)} to ${await DownloadPlugin(Commit)}`);
}

export function InstallCommit(Commit: string): Promise<void> {
  return new Promise((Resolve, Reject) => {
    execFile("npm", ["install", "-g", `github:${GitHubRepo}#${Commit}`, "--no-audit", "--no-fund"], {
      shell: true,
      timeout: 15 * 60 * 1000,
      windowsHide: true,
    }, (Trouble, _Output, Problem) => {
      if (Trouble) {
        Reject(new Error(`npm could not install commit ${Commit.slice(0, 7)}: ${String(Problem || Trouble.message).trim().slice(-400)}`));

        return;
      }

      DownloadPlugin(Commit).then(() => {
        Remember(Commit);
        Resolve();
      }, Reject);
    });
  });
}
