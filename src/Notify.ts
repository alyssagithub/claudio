import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import notifier from "node-notifier";

const ScriptPath = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "Notify.ps1");
const IconFile = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "Icon.png");
const ClipboardPath = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "Clipboard.ps1");
const ToastPath = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "Toast.ps1");
const SnoreToast = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "node_modules", "node-notifier", "vendor", "snoreToast", "snoretoast-x64.exe");
const ToastShortcut = path.join(process.env.APPDATA || "", "Microsoft", "Windows", "Start Menu", "Programs", "Claudio.lnk");

export function RegisterToasts() {
  if (process.platform !== "win32" || !process.env.APPDATA || fs.existsSync(ToastShortcut)) {
    return;
  }

  execFile(SnoreToast, ["-install", "Claudio", path.join(process.env.SystemRoot || "C:\\Windows", "System32", "WindowsPowerShell", "v1.0", "powershell.exe"), "Claudio"], { windowsHide: true }, (Error) => {
    if (Error) {
      console.error(`Could not register Claudio for desktop notifications: ${Error.message.slice(0, 200)}`);
    }
  });
}

type ToastOptions = {
  Flash?: boolean;
  Toast?: boolean;
  Banner?: boolean;
  Sound?: boolean;
  Anywhere?: boolean;
  Seconds?: number;
};

type ClipboardPicture = {
  data: string;
  mediaType: string;
  id: string;
};

let LastShownAt = 0;

function Clean(Value: unknown, Limit: number): string {
  return String(Value).replace(/\s+/g, " ").trim().slice(0, Limit);
}

export function ShowToast(Title: unknown, Body: unknown, Options?: ToastOptions | null): boolean {
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

    execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ToastPath], {
      windowsHide: true,
      env: { ...process.env, CLAUDIO_TITLE: Heading, CLAUDIO_BODY: Detail, CLAUDIO_ICON: IconFile, CLAUDIO_APP_ID: "Claudio", CLAUDIO_TOAST_SECONDS: String(Wanted.Seconds || 0) },
    }, (Trouble, Said) => {
      if (!Trouble && Said.includes("shown")) {
        return;
      }

      notifier.notify({
        appID: "Claudio",
        title: Heading,
        message: Detail,
        icon: IconFile,
        sound: false,
        wait: false,
      }, (Failure: Error | null) => {
        if (Failure) {
          console.error(`Toast failed: ${String(Failure).slice(0, 200)}`);
        }
      });
    });
  });

  return true;
}

const QuietPath = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "Quiet.ps1");

export function QuietFlash(Seconds: number): Promise<() => void> {
  return new Promise((Resolve) => {
    if (process.platform !== "win32") {
      Resolve(() => {});
      return;
    }

    const Started = execFile("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", QuietPath], {
      windowsHide: true,
      env: { ...process.env, CLAUDIO_QUIET_SECONDS: String(Seconds) },
    }, () => {});

    const Release = () => {
      try {
        Started.stdin!.write("done\n");
      } catch {
        return;
      }
    };

    let Settled = false;

    const Ready = () => {
      if (!Settled) {
        Settled = true;
        Resolve(Release);
      }
    };

    Started.stdout!.on("data", (Chunk: Buffer) => {
      if (Chunk.toString("utf8").includes("quiet")) {
        Ready();
      }
    });
    Started.on("exit", Ready);
    setTimeout(Ready, 4000);
  });
}

export function WriteClipboard(Text: string): Promise<boolean> {
  return new Promise<boolean>((Resolve) => {
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

function RunClipboard(Mode: string, Marker?: string | null): Promise<string> {
  return new Promise<string>((Resolve) => {
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

let Armed: { Marker: string; Image: ClipboardPicture } | null = null;

function Picture(Data: string): ClipboardPicture {
  return {
    data: Data,
    mediaType: "image/png",
    id: crypto.createHash("sha1").update(Data).digest("hex").slice(0, 16),
  };
}

export async function ArmClipboard(Marker: string): Promise<string> {
  const [Outcome, Data] = (await RunClipboard("arm", Marker)).split(/\r?\n/);

  if (Outcome === "armed" && Data && Data.length >= 64) {
    Armed = { Marker, Image: Picture(Data.trim()) };
  }

  return Outcome;
}

export async function DisarmClipboard(Marker: string): Promise<string> {
  return await RunClipboard("disarm", Marker);
}

export function ReadClipboardImage(Marker?: string | null): Promise<ClipboardPicture | null> {
  return new Promise<ClipboardPicture | null>((Resolve) => {
    if (Marker && Armed && Armed.Marker === Marker) {
      Resolve(Armed.Image);
      return;
    }

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

      Resolve(Picture(Data));
    });
  });
}