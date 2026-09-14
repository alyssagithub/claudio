import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { GitHubRepo, Version } from "./Config.js";

const InstalledFile = path.join(os.homedir(), ".claudio", "installed.json");

type InstalledRecord = {
  commit: string;
  at: number;
};

type CommitRecord = {
  sha: string;
  commit: {
    message: string;
    committer: {
      date: string;
    };
  };
};

function Installed(): InstalledRecord | null {
  try {
    return JSON.parse(fs.readFileSync(InstalledFile, "utf8").replace(/^\uFEFF/, "")) as InstalledRecord;
  } catch {
    return null;
  }
}

async function LatestCommit(): Promise<CommitRecord> {
  const Response = await fetch(`https://api.github.com/repos/${GitHubRepo}/commits/main`, {
    headers: { "User-Agent": "claudio", "Cache-Control": "no-cache" },
  });

  if (!Response.ok) {
    throw new Error(`GitHub answered ${Response.status}`);
  }

  return await Response.json() as CommitRecord;
}

export async function ReportVersion() {
  const Here = Installed();

  console.log(`Claudio ${Version}`);

  if (Here && typeof Here.commit === "string") {
    console.log(`Installed ${Here.commit.slice(0, 7)} on ${new Date(Here.at).toLocaleString()}`);
  } else {
    console.log("Installed by hand rather than by the installer, so there is no commit recorded.");
  }

  let Newest: CommitRecord;

  try {
    Newest = await LatestCommit();
  } catch (Error) {
    console.log(`Could not check for a newer version: ${(Error as NodeJS.ErrnoException).message}`);
    return;
  }

  const When = new Date(Newest.commit.committer.date).toLocaleString();

  if (Here && Here.commit === Newest.sha) {
    console.log(`Up to date. Newest is ${Newest.sha.slice(0, 7)} from ${When}.`);
    return;
  }

  console.log(`\nA newer version is out: ${Newest.sha.slice(0, 7)} from ${When}`);
  console.log(`  ${Newest.commit.message.split("\n")[0]}`);
  console.log("\nGet it with:");
  console.log("  irm https://raw.githubusercontent.com/alyssagithub/claudio/main/install.ps1 | iex");
}