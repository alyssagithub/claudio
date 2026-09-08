import crypto from "node:crypto";
import path from "node:path";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import notifier from "node-notifier";

const ScriptPath = path.resolve(fileURLToPath(import.meta.url), "..", "Notify.ps1");
const IconFile = path.resolve(fileURLToPath(import.meta.url), "..", "Icon.png");
const ClipboardPath = path.resolve(fileURLToPath(import.meta.url), "..", "Clipboard.ps1");


let LastShownAt = 0;

function Clean(Value, Limit) {
  return String(Value).replace(/\s+/g, " ").trim().slice(0, Limit);
}

export function ShowToast(Title, Body, Options) {
  const Wanted = Options || {};

  if (process.platform !== "win32" || Date.now() - LastShownAt < 2000) {
    return false;
  }

  if (!Wanted.Flash && !Wanted.Toast && !Wanted.Banner && !Wanted.Sound) {
    return false;
  }

  const Heading = Clean(Title, 60);
  const Detail = Clean(Body, 160);

  execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ScriptPath], {
    windowsHide: true,
    env: {
      ...process.env,
      CLAUDIO_TITLE: Heading,
      CLAUDIO_BODY: Detail,
      CLAUDIO_NO_FLASH: Wanted.Flash ? "0" : "1",
      CLAUDIO_TOAST: Wanted.Toast ? "1" : "0",
      CLAUDIO_BANNER: Wanted.Banner ? "1" : "0",
      CLAUDIO_ANYWHERE: Wanted.Anywhere ? "1" : "0",
      CLAUDIO_ICON: IconFile,
      CLAUDIO_SOUND: Wanted.Sound ? "1" : "0",
    },
  }, (Error, Stdout, Stderr) => {
    if (Error) {
      console.error(`Notification failed: ${(Stderr || Error.message).slice(0, 300)}`);
      return;
    }

    if (!Stdout.includes("quiet")) {
      LastShownAt = Date.now();
    }

    if (!Stdout.includes("toast")) {
      return;
    }

    notifier.notify({
      appID: "Claudio",
      title: Heading,
      message: Detail,
      icon: IconFile,
      sound: false,
      wait: false,
    }, (Failure) => {
      if (Failure) {
        console.error(`Toast failed: ${String(Failure).slice(0, 200)}`);
      }
    });
  });

  return true;
}

export function WriteClipboard(Text) {
  return new Promise((Resolve) => {
    if (process.platform !== "win32") {
      Resolve(false);
      return;
    }

    execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", "Set-Clipboard -Value $env:CLAUDIO_TEXT"], {
      windowsHide: true,
      env: { ...process.env, CLAUDIO_TEXT: Text },
    }, (Error) => {
      Resolve(!Error);
    });
  });
}

function RunClipboard(Mode, Marker) {
  return new Promise((Resolve) => {
    if (process.platform !== "win32") {
      Resolve("");
      return;
    }

    execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-STA", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ClipboardPath], {
      windowsHide: true,
      maxBuffer: 32 * 1024 * 1024,
      env: { ...process.env, CLAUDIO_CLIPBOARD_MODE: Mode, CLAUDIO_CLIPBOARD_MARKER: Marker || "" },
    }, (Error, Stdout) => {
      Resolve(Error ? "" : String(Stdout || "").trim());
    });
  });
}

export async function ArmClipboard(Marker) {
  return await RunClipboard("arm", Marker);
}

export async function DisarmClipboard(Marker) {
  return await RunClipboard("disarm", Marker);
}

export function ReadClipboardImage() {
  return new Promise((Resolve) => {
    if (process.platform !== "win32") {
      Resolve(null);
      return;
    }

    execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-STA", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ClipboardPath], {
      windowsHide: true,
      maxBuffer: 32 * 1024 * 1024,
      env: { ...process.env, CLAUDIO_CLIPBOARD_MODE: "read" },
    }, (Error, Stdout) => {
      const Data = String(Stdout || "").replace(/\s+/g, "");

      if (Error || Data === "none" || Data.length < 64) {
        Resolve(null);
        return;
      }

      Resolve({
        data: Data,
        mediaType: "image/png",
        id: crypto.createHash("sha1").update(Data).digest("hex").slice(0, 16),
      });
    });
  });
}