import fs from "node:fs";
import path from "node:path";
import { GitHubRepo, InstalledPluginFile, PluginFileName } from "./Config.js";
import { GetPluginsFolder } from "./StudioPaths.js";

let Releases = { At: 0, List: [] };

function Compare(Left, Right) {
  const Parts = (Text) => String(Text).replace(/^v/, "").split(".").map((Piece) => Number(Piece) || 0);
  const First = Parts(Left);
  const Second = Parts(Right);

  for (let At = 0; At < 3; At += 1) {
    if ((First[At] || 0) !== (Second[At] || 0)) {
      return (First[At] || 0) > (Second[At] || 0) ? 1 : -1;
    }
  }

  return 0;
}

export function IsNewer(Candidate, Current) {
  return Compare(Candidate, Current) > 0;
}

export async function ListReleases() {
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

    const Found = (await Response.json())
      .filter((Entry) => !Entry.draft && (Entry.assets || []).some((Asset) => Asset.name === PluginFileName))
      .map((Entry) => ({
        version: String(Entry.tag_name).replace(/^v/, ""),
        name: Entry.name || Entry.tag_name,
        prerelease: Entry.prerelease === true,
        notes: String(Entry.body || "").slice(0, 400),
      }));

    Releases = { At: Date.now(), List: Found };
  } catch (Error) {
    console.error("Could not list releases: " + Error.message);
  }

  return Releases.List;
}

export async function InstallVersion(Version) {
  const Response = await fetch(`https://api.github.com/repos/${GitHubRepo}/releases/tags/v${Version}`, {
    headers: { "User-Agent": "claudio-installer" },
  });

  if (!Response.ok) {
    throw new Error(`No release tagged v${Version}`);
  }

  const Release = await Response.json();
  const Asset = (Release.assets || []).find((Entry) => Entry.name === PluginFileName);

  if (!Asset) {
    throw new Error(`Release ${Release.tag_name} has no ${PluginFileName}`);
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

// Studio reads this file at startup, so it must never see half of one. An
// error page from a CDN is also a valid 200, and rbxm files start with a
// known magic string, so check it before it lands.
export function InstalledPluginVersion() {
  try {
    return JSON.parse(fs.readFileSync(InstalledPluginFile, "utf8").replace(/^﻿/, "")).version || null;
  } catch {
    return null;
  }
}

function RememberInstalled(Installed) {
  try {
    fs.mkdirSync(path.dirname(InstalledPluginFile), { recursive: true });
    fs.writeFileSync(InstalledPluginFile, JSON.stringify({ version: Installed }, null, 2));
  } catch (Error) {
    console.error("Could not record the installed plugin version: " + Error.message);
  }
}

function WritePlugin(Target, Body) {
  if (Body.length < 1024 || !Body.subarray(0, 8).toString("binary").startsWith("<roblox")) {
    throw new Error("That download is not a Roblox model file");
  }

  fs.writeFileSync(`${Target}.claudio-writing`, Body);
  fs.renameSync(`${Target}.claudio-writing`, Target);
}

export async function InstallPlugin(LocalPath) {
  const PluginsFolder = GetPluginsFolder();
  const Target = path.join(PluginsFolder, PluginFileName);

  fs.mkdirSync(PluginsFolder, { recursive: true });

  if (LocalPath) {
    fs.copyFileSync(LocalPath, Target);
    console.log(`Copied ${LocalPath} to ${Target}`);
    return;
  }

  const ReleaseResponse = await fetch(`https://api.github.com/repos/${GitHubRepo}/releases/latest`, {
    headers: { "User-Agent": "claudio-installer" },
  });

  if (!ReleaseResponse.ok) {
    throw new Error(`Could not read the latest release of ${GitHubRepo} (${ReleaseResponse.status})`);
  }

  const Release = await ReleaseResponse.json();
  const Asset = (Release.assets || []).find((Entry) => Entry.name === PluginFileName);

  if (!Asset) {
    throw new Error(`Release ${Release.tag_name} has no asset named ${PluginFileName}`);
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
