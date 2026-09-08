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

export function Describe(Presence) {
  const Running = (Presence.processes || []).length;
  const Since = Presence.lastSeen ? Date.now() - Presence.lastSeen : null;
  const Fresh = Since !== null && Since < 8000;

  if (Fresh) {
    const Live = Presence.runtimeSeen && Date.now() - Presence.runtimeSeen < 6000;
    const Busy = [];

    if (Live) {
      Busy.push("a play session is running and reachable");
    }

    if (Presence.queued > 0) {
      Busy.push(`${Presence.queued} queued`);
    }

    if (Presence.waiting > 0) {
      Busy.push(`${Presence.waiting} in flight`);
    }

    const Line = `Connected. The plugin checked in ${Math.round(Since / 1000)}s ago${Busy.length > 0 ? `, ${Busy.join(" and ")}` : ""}.`;

    if (Live && Presence.canRun === false) {
      return `${Line} It cannot run code, though, because loadstring is off for this place: select ServerScriptService in the Explorer and tick LoadStringEnabled in its Properties, then start the playtest again. Claudio cannot set it, because the property is not readable or writable from any script.`;
    }

    return Line;
  }

  if (Running === 0) {
    return "No Studio is running on this machine, so nothing can reach the place. Ask the user to open the place rather than opening it yourself, because a second Studio on the same place will fight the first over the files on disk.";
  }

  const Waited = Since === null ? "has never checked in" : `last checked in ${Math.round(Since / 1000)}s ago`;

  return `Studio is running (${Running === 1 ? "1 process" : `${Running} processes`}) but the Claudio plugin ${Waited}. Studio is open, so do not open it again. The plugin may still be loading, the place may not be open yet, or the plugin may be disabled.`;
}
