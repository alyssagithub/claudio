import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { RunningTurns, ToolsRunning } from "./ClaudeSession.js";
import { InstallCommit, Installed, IsCheckout, LatestCommit } from "./PluginInstaller.js";

export type PendingTurn = {
  conversationId: string;
  model: string;
  effort: string | null;
  mode: string;
  outputStyle: string;
};

const PendingFile = path.join(os.homedir(), ".claudio", "continue-after-update.json");
let Updating = false;

async function WaitForQuiet() {
  while (ToolsRunning()) {
    await new Promise((Resolve) => setTimeout(Resolve, 2000));
  }
}

async function CheckForUpdate(Port: number) {
  if (Updating) {
    return;
  }

  Updating = true;

  try {
    const Newest = await LatestCommit();
    const Here = Installed();

    if (Here && Here.commit === Newest.sha) {
      return;
    }

    console.log(`Updating Claudio to commit ${Newest.sha.slice(0, 7)}: ${Newest.commit.message.split("\n")[0]}`);
    await InstallCommit(Newest.sha);
    await WaitForQuiet();
    fs.writeFileSync(PendingFile, JSON.stringify(RunningTurns()));

    const Restarter = spawn(process.execPath, [process.argv[1], "restart", "--port", String(Port)], {
      detached: true,
      stdio: "ignore",
      windowsHide: true,
    });

    Restarter.on("error", (Trouble) => console.error(`Could not restart onto the update: ${Trouble.message}`));
    Restarter.unref();
  } catch (Trouble) {
    console.error(`Could not update Claudio: ${(Trouble as Error).message}`);
  } finally {
    Updating = false;
  }
}

export function StartAutoUpdate(Port: number) {
  if (IsCheckout()) {
    return;
  }

  setTimeout(() => CheckForUpdate(Port), 60000).unref();
  setInterval(() => CheckForUpdate(Port), 3 * 60 * 60 * 1000).unref();
}

export function TakePendingTurns(): PendingTurn[] {
  try {
    const Pending = JSON.parse(fs.readFileSync(PendingFile, "utf8")) as PendingTurn[];

    fs.rmSync(PendingFile, {force: true});

    return Array.isArray(Pending) ? Pending : [];
  } catch {
    return [];
  }
}
