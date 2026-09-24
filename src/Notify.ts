import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFile, spawn } from "node:child_process";
import type { ChildProcess } from "node:child_process";
import readline from "node:readline";
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

  execFile(SnoreToast, ["-install", "Claudio", path.join(process.env.SystemRoot || "C:\\Windows", "System32", "WindowsPowerShell", "v1.0", "powershell.exe"), "Claudio"], {windowsHide: true}, (Error) => {
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

  LastShownAt = Date.now();
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

    if (!Stdout.includes("toast")) {
      return;
    }

    execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ToastPath], {
      windowsHide: true,
      env: {
        ...process.env,
        CLAUDIO_TITLE: Heading,
        CLAUDIO_BODY: Detail,
        CLAUDIO_ICON: IconFile,
        CLAUDIO_APP_ID: "Claudio",
        CLAUDIO_TOAST_SECONDS: String(Wanted.Seconds || 0),
      },
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
          console.error(`Desktop notification failed: ${String(Failure).slice(0, 200)}`);
        }
      });
    });
  });

  return true;
}

const QuietPath = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src", "Quiet.ps1");
const FlashingSaved = path.join(process.env.USERPROFILE || "", ".claudio", "flashing.txt");

export function RestoreFlashing() {
  if (process.platform !== "win32" || !fs.existsSync(FlashingSaved)) {
    return;
  }

  const Before = fs.readFileSync(FlashingSaved, "utf8").replace(/^\uFEFF/, "").trim();
  const Key = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced";
  const Command = Before === "-1"
    ? `Remove-ItemProperty -Path '${Key}' -Name TaskbarFlashing -ErrorAction SilentlyContinue`
    : `Set-ItemProperty -Path '${Key}' -Name TaskbarFlashing -Value ${/^\d+$/.test(Before) ? Before : 1} -Type DWord`;

  execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", Command], {windowsHide: true}, () => {
    fs.rmSync(FlashingSaved, {force: true});
  });
}

export function QuietFlash(Seconds: number): Promise<() => void> {
  return new Promise((Resolve) => {
    if (process.platform !== "win32") {
      Resolve(() => {});
      return;
    }

    const Started = execFile("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", QuietPath], {
      windowsHide: true,
      env: {
        ...process.env,
        CLAUDIO_QUIET_SECONDS: String(Seconds),
      },
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

    const Writing = execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", "[Console]::InputEncoding = [Text.Encoding]::UTF8; Set-Clipboard -Value ([Console]::In.ReadToEnd())"], {windowsHide: true}, (Error) => {
      Resolve(!Error);
    });

    Writing.stdin!.end(Text, "utf8");
  });
}

let Helper: ChildProcess | null = null;
const Replies: ((Line: string) => void)[] = [];

export function AskClipboard(Command: string, Marker = ""): Promise<string> {
  if (process.platform !== "win32") {
    return Promise.resolve("");
  }

  if (!Helper) {
    const Started = spawn("powershell.exe", ["-NoProfile", "-NonInteractive", "-STA", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ClipboardPath], {
      windowsHide: true,
      stdio: ["pipe", "pipe", "ignore"],
    });

    readline.createInterface({input: Started.stdout!}).on("line", (Line) => {
      const Reply = Replies.shift();

      if (Reply) {
        Reply(Line);
      }
    });
    const Stop = () => {
      if (Helper === Started) {
        Helper = null;
      }

      for (const Reply of Replies.splice(0)) {
        Reply("");
      }
    };

    Started.on("exit", Stop);
    Started.on("error", Stop);
    Started.stdin!.on("error", Stop);
    Helper = Started;
  }

  const Asked = Helper;

  return new Promise<string>((Resolve) => {
    const Timer = setTimeout(() => {
      Resolve("");
      Asked.kill();
    }, 15000);

    Replies.push((Line) => {
      clearTimeout(Timer);
      Resolve(Line);
    });
    Asked.stdin!.write(`${Command}\t${Marker.replace(/[\t\r\n]/g, " ")}\n`);
  });
}

let Armed: { Marker: string; Image: ClipboardPicture } | null = null;
let Generation = 0;
let Current = "";
const Dropped: string[] = [];

function Picture(Data: string): ClipboardPicture {
  return {
    data: Data,
    mediaType: "image/png",
    id: crypto.createHash("sha1").update(Data).digest("hex").slice(0, 16),
  };
}

function Remember(Marker: string, Answer: string) {
  const [Outcome, Data] = Answer.split("\t");

  if (Outcome === "armed" && Data && Data.length >= 64) {
    Armed = {
      Marker,
      Image: Picture(Data),
    };
  }

  return Outcome;
}

export async function ArmClipboard(Marker: string): Promise<string> {
  if (Dropped.includes(Marker)) {
    return "disarmed";
  }

  Generation += 1;
  Current = Marker;

  const Mine = Generation;
  const Outcome = Remember(Marker, await AskClipboard("arm", Marker));

  if (Mine !== Generation || Dropped.includes(Marker)) {
    return Outcome;
  }

  const Began = Date.now();
  let Busy = false;

  const Watch = setInterval(async () => {
    if (Mine !== Generation || Dropped.includes(Marker) || Date.now() - Began > 10 * 60 * 1000) {
      clearInterval(Watch);
      return;
    }

    if (Busy) {
      return;
    }

    Busy = true;
    Remember(Marker, await AskClipboard("check", Marker));
    Busy = false;
  }, 300);

  return Outcome;
}

export async function DisarmClipboard(Marker: string): Promise<string> {
  Dropped.push(Marker);
  Dropped.splice(0, Math.max(0, Dropped.length - 50));

  if (Marker === Current) {
    Generation += 1;
    Current = "";
    Armed = null;
  }

  return await AskClipboard("disarm", Marker);
}

export async function ReadClipboardImage(Marker?: string | null): Promise<ClipboardPicture | null> {
  if (Marker && Armed && Armed.Marker === Marker) {
    return Armed.Image;
  }

  const Data = (await AskClipboard("read")).trim();

  return Data === "" || Data === "none" || Data === "failed" || Data.length < 64 ? null : Picture(Data);
}