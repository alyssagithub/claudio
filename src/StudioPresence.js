import { exec } from "node:child_process";

const Names = ["RobloxStudioBeta", "RobloxStudio"];

function Run(Command) {
  return new Promise((Resolve) => {
    exec(Command, { timeout: 8000, windowsHide: true }, (Error, Output) => Resolve(Output || ""));
  });
}

export async function StudioProcesses() {
  if (process.platform === "win32") {
    const Output = await Run(`powershell -NoProfile -Command "Get-Process | Where-Object { $_.Name -like 'RobloxStudio*' } | Select-Object -ExpandProperty Id"`);

    return Output.split(/\r?\n/).map((Line) => Number(Line.trim())).filter((Id) => Number.isFinite(Id) && Id > 0);
  }

  if (process.platform === "darwin") {
    const Output = await Run(`pgrep -f "RobloxStudio"`);

    return Output.split(/\r?\n/).map((Line) => Number(Line.trim())).filter((Id) => Number.isFinite(Id) && Id > 0);
  }

  return [];
}

function Health(Presence) {
  if (!Presence.bridge) {
    return "";
  }

  const Parts = [`Claudio ${Presence.bridge}`];

  if (Presence.from) {
    Parts.push(`from ${Presence.from}`);
  }

  if (Presence.upSince) {
    const Minutes = Math.round((Date.now() - Presence.upSince) / 60000);

    Parts.push(`up ${Minutes < 1 ? "under a minute" : `${Minutes}m`}`);
  }

  if (Presence.tools) {
    Parts.push(`${Presence.tools} tools`);
  }

  const Line = ` ${Parts.join(", ")}.`;

  if (Presence.plugin && Presence.plugin !== Presence.bridge) {
    return `${Line} The plugin is ${Presence.plugin} and the bridge is ${Presence.bridge}, so they do not match: reinstall the plugin, or restart the bridge from the copy you meant to run, before trusting anything either of them says.`;
  }

  return Line;
}

export function Describe(Presence) {
  const Running = (Presence.processes || []).length;
  const Since = Presence.lastSeen ? Date.now() - Presence.lastSeen : null;
  const Fresh = Since !== null && Since < 8000;

  if (Fresh) {
    const Live = Presence.runtimeSeen && Date.now() - Presence.runtimeSeen < 6000;
    const Busy = [];

    if (Live) {
      const Attached = Presence.clients;

      Busy.push(`a play session is reachable${Attached ? ` with ${Attached === 1 ? "1 client" : `${Attached} clients`}` : " with no client attached yet"}`);
    }

    if (Presence.queued > 0) {
      Busy.push(`${Presence.queued} queued`);
    }

    if (Presence.waiting > 0) {
      Busy.push(`${Presence.waiting} in flight`);
    }

    const Line = `Connected. The plugin checked in ${Math.round(Since / 1000)}s ago${Busy.length > 0 ? `, ${Busy.join(" and ")}` : ""}.${Health(Presence)}`;

    if (Live && Presence.canRun === false) {
      return `${Line} It cannot run code, though, because Claudio's plugin is not running inside the play session, so there is nothing to build the code with. Stop the playtest and start it again, and if that does not help, reinstall the plugin.`;
    }

    return Line;
  }

  if (Running === 0) {
    return "No Studio is running on this machine, so nothing can reach the place. Ask the user to open the place rather than opening it yourself, because a second Studio on the same place will fight the first over the files on disk.";
  }

  const Waited = Since === null ? "has never checked in" : `last checked in ${Math.round(Since / 1000)}s ago`;

  return `Studio is running (${Running === 1 ? "1 process" : `${Running} processes`}) but the Claudio plugin ${Waited}. Studio is open, so do not open it again. The plugin may still be loading, the place may not be open yet, or the plugin may be disabled.`;
}