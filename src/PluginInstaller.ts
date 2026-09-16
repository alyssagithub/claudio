import fs from "node:fs";
import path from "node:path";
import { exec } from "node:child_process";
import { GitHubRepo, InstalledPluginFile, PluginFileName } from "./Config.js";
import { GetPluginsFolder } from "./StudioPaths.js";

type ReleaseEntry = {
  version: string;
  name: string;
  prerelease: boolean;
  notes: string;
};

type GitHubAsset = {
  name: string;
  browser_download_url: string;
};

type GitHubRelease = {
  tag_name: string;
  name?: string;
  draft?: boolean;
  prerelease?: boolean;
  body?: string;
  assets?: GitHubAsset[];
};

let Releases: { At: number; List: ReleaseEntry[] } = { At: 0, List: [] };

export function LooksLikeVersion(Text: unknown): Text is string {
  return typeof Text === "string" && /^v?\d+(\.\d+)*$/.test(Text.trim());
}

function Compare(Left: string, Right: string): number {
  const Parts = (Text: string) => String(Text).trim().replace(/^v/, "").split(".").map((Piece) => Number(Piece) || 0);
  const First = Parts(Left);
  const Second = Parts(Right);

  for (let At = 0; At < Math.max(First.length, Second.length); At += 1) {
    if ((First[At] || 0) !== (Second[At] || 0)) {
      return (First[At] || 0) > (Second[At] || 0) ? 1 : -1;
    }
  }

  return 0;
}

export function IsNewer(Candidate: unknown, Current: unknown): boolean {
  if (!LooksLikeVersion(Candidate) || !LooksLikeVersion(Current)) {
    return false;
  }

  return Compare(Candidate, Current) > 0;
}

export function NewestRelease(Releases: ReleaseEntry[]): ReleaseEntry | null {
  let Best: ReleaseEntry | null = null;

  for (const Entry of Releases) {
    if (Entry.prerelease || !LooksLikeVersion(Entry.version)) {
      continue;
    }

    if (!Best || IsNewer(Entry.version, Best.version)) {
      Best = Entry;
    }
  }

  return Best;
}

export async function ListReleases(): Promise<ReleaseEntry[]> {
  if (Date.now() - Releases.At < 600000 && Releases.List.length > 0) {
    return Releases.List;
  }

  try {
    const Response = await fetch(`https://api.github.com/repos/${GitHubRepo}/releases`, {
      headers: { "User-Agent": "claudio-installer" },
    });

    if (!Response.ok) {
      return Releases.List;
    }

    const Found = (await Response.json() as GitHubRelease[])
      .filter((Entry) => !Entry.draft && (Entry.assets || []).some((Asset) => Asset.name === PluginFileName))
      .map((Entry) => ({
        version: String(Entry.tag_name).replace(/^v/, ""),
        name: Entry.name || Entry.tag_name,
        prerelease: Entry.prerelease === true,
        notes: String(Entry.body || "").slice(0, 400),
      }));

    Releases = { At: Date.now(), List: Found };
  } catch (Error) {
    console.error("Could not list releases: " + (Error as NodeJS.ErrnoException).message);
  }

  return Releases.List;
}

function FromGitHub(Url: string): boolean {
  try {
    const Parsed = new URL(Url);

    return Parsed.protocol === "https:" && /(^|\.)github(usercontent)?\.com$/.test(Parsed.hostname);
  } catch {
    return false;
  }
}

async function CommitFor(Version: string): Promise<string> {
  const Response = await fetch(`https://api.github.com/repos/${GitHubRepo}/commits/v${Version}`, {
    headers: { "User-Agent": "claudio-installer" },
  });

  if (!Response.ok) {
    throw new Error(`Could not find the commit for v${Version}`);
  }

  const Found = (await Response.json() as { sha?: unknown }).sha;

  if (typeof Found !== "string" || !/^[0-9a-f]{40}$/.test(Found)) {
    throw new Error(`GitHub gave an unusable commit for v${Version}`);
  }

  return Found;
}

async function PackageFor(Version: string): Promise<string> {
  const Response = await fetch(`https://api.github.com/repos/${GitHubRepo}/releases/tags/v${Version}`, {
    headers: { "User-Agent": "claudio-installer" },
  });

  if (!Response.ok) {
    return `https://github.com/${GitHubRepo}/archive/${await CommitFor(Version)}.tar.gz`;
  }

  const Packed = ((await Response.json() as GitHubRelease).assets || []).find((Entry) => Entry.name.endsWith(".tgz"));

  if (!Packed || !FromGitHub(Packed.browser_download_url)) {
    return `https://github.com/${GitHubRepo}/archive/${await CommitFor(Version)}.tar.gz`;
  }

  return Packed.browser_download_url;
}

export async function InstallBridge(Version: string): Promise<string> {
  const Package = await PackageFor(Version);
  const Commit = await CommitFor(Version);

  await new Promise<void>((Resolve, Reject) => {
    exec(`npm install -g ${Package}`, { timeout: 300000 }, (Trouble, Stdout, Stderr) => {
      if (Trouble) {
        const Said = `${Stderr || ""}${Stdout || ""}`.trim().split(/\r?\n/).slice(-3).join(" ");

        Reject(new Error(`npm could not install the bridge for v${Version}: ${Said}`));

        return;
      }

      Resolve();
    });
  });

  return Commit;
}

export async function InstallVersion(Version: string): Promise<string> {
  if (!LooksLikeVersion(Version)) {
    throw new Error("A version looks like 1.0.0");
  }

  const Response = await fetch(`https://api.github.com/repos/${GitHubRepo}/releases/tags/v${Version}`, {
    headers: { "User-Agent": "claudio-installer" },
  });

  if (!Response.ok) {
    throw new Error(`No release tagged v${Version}`);
  }

  const Release = await Response.json() as GitHubRelease;
  const Asset = (Release.assets || []).find((Entry) => Entry.name === PluginFileName);

  if (!Asset) {
    throw new Error(`Release ${Release.tag_name} has no ${PluginFileName}`);
  }

  if (!FromGitHub(Asset.browser_download_url)) {
    throw new Error("That release points its download somewhere other than GitHub");
  }

  const Download = await fetch(Asset.browser_download_url, { headers: { "User-Agent": "claudio-installer" } });

  if (!Download.ok) {
    throw new Error(`Download failed (${Download.status})`);
  }

  const PluginsFolder = GetPluginsFolder();

  fs.mkdirSync(PluginsFolder, { recursive: true });
  WritePlugin(path.join(PluginsFolder, PluginFileName), Buffer.from(await Download.arrayBuffer()));
  RememberInstalled(String(Release.tag_name).replace(/^v/, ""));

  return Release.tag_name;
}

export function InstalledPluginVersion(): string | null {
  try {
    const Recorded = (JSON.parse(fs.readFileSync(InstalledPluginFile, "utf8").replace(/^﻿/, "")) as { version?: unknown }).version;

    return LooksLikeVersion(Recorded) ? Recorded.replace(/^v/, "") : null;
  } catch {
    return null;
  }
}

function RememberInstalled(Installed: string | null): void {
  try {
    fs.mkdirSync(path.dirname(InstalledPluginFile), { recursive: true });
    fs.writeFileSync(InstalledPluginFile, JSON.stringify({ version: Installed }, null, 2));
  } catch (Error) {
    console.error("Could not record the installed plugin version: " + (Error as NodeJS.ErrnoException).message);
  }
}

function WritePlugin(Target: string, Body: Buffer): void {
  if (Body.length < 1024 || !Body.subarray(0, 8).toString("binary").startsWith("<roblox")) {
    throw new Error("That download is not a Roblox model file");
  }

  const Temporary = `${Target}.claudio-writing`;

  try {
    fs.writeFileSync(Temporary, Body);
    fs.renameSync(Temporary, Target);
  } catch (Error) {
    fs.rmSync(Temporary, { force: true });

    throw Error;
  }
}

export async function InstallPlugin(LocalPath?: string | null): Promise<void> {
  const PluginsFolder = GetPluginsFolder();
  const Target = path.join(PluginsFolder, PluginFileName);

  fs.mkdirSync(PluginsFolder, { recursive: true });

  if (LocalPath) {
    WritePlugin(Target, fs.readFileSync(LocalPath));
    RememberInstalled(null);
    console.log(`Copied ${LocalPath} to ${Target}`);

    return;
  }

  const ReleaseResponse = await fetch(`https://api.github.com/repos/${GitHubRepo}/releases/latest`, {
    headers: { "User-Agent": "claudio-installer" },
  });

  if (!ReleaseResponse.ok) {
    throw new Error(`Could not read the latest release of ${GitHubRepo} (${ReleaseResponse.status})`);
  }

  const Release = await ReleaseResponse.json() as GitHubRelease;
  const Asset = (Release.assets || []).find((Entry) => Entry.name === PluginFileName);

  if (!Asset) {
    throw new Error(`Release ${Release.tag_name} has no asset named ${PluginFileName}`);
  }

  if (!FromGitHub(Asset.browser_download_url)) {
    throw new Error("That release points its download somewhere other than GitHub");
  }

  const AssetResponse = await fetch(Asset.browser_download_url, {
    headers: { "User-Agent": "claudio-installer" },
  });

  if (!AssetResponse.ok) {
    throw new Error(`Download failed (${AssetResponse.status})`);
  }

  WritePlugin(Target, Buffer.from(await AssetResponse.arrayBuffer()));
  RememberInstalled(String(Release.tag_name).replace(/^v/, ""));
  console.log(`Installed ${PluginFileName} ${Release.tag_name} to ${Target}`);
}