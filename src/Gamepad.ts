import { spawn, type ChildProcess } from "node:child_process";
import path from "node:path";
import readline from "node:readline";
import { fileURLToPath } from "node:url";

const Source = path.resolve(fileURLToPath(import.meta.url), "..", "..", "..", "src");

const Keys: Record<string, number[]> = {
  A: [57],
  B: [48],
  X: [56],
  Y: [55],
  L1: [82],
  L2: [69],
  L3: [70],
  R1: [79],
  R2: [80],
  R3: [72],
  Select: [81],
  Start: [85],
  LeftStickUp: [87],
  LeftStickDown: [83],
  LeftStickLeft: [65],
  LeftStickRight: [68],
  LeftStickUpLeft: [87, 65],
  LeftStickUpRight: [87, 68],
  LeftStickDownLeft: [83, 65],
  LeftStickDownRight: [83, 68],
  RightStickUp: [73],
  RightStickDown: [75],
  RightStickLeft: [74],
  RightStickRight: [76],
  RightStickUpLeft: [73, 74],
  RightStickUpRight: [73, 76],
  RightStickDownLeft: [75, 74],
  RightStickDownRight: [75, 76],
};

export const PadInputs: [string, ...string[]] = ["DPadUp", "DPadDown", "DPadLeft", "DPadRight", ...Object.keys(Keys)];

let Helper: ChildProcess | null = null;
const Replies: ((Line: string) => void)[] = [];

function Ask(Line: string): Promise<string> {
  if (!Helper) {
    const Started = spawn("powershell.exe", ["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", path.join(Source, "Gamepad.ps1")], {
      windowsHide: true,
      stdio: ["pipe", "pipe", "ignore"],
      env: {...process.env, CLAUDIO_PAD_TITLE: path.join(Source, "EmulatorTitle.png")},
    });
    const Stop = () => {
      if (Helper === Started) {
        Helper = null;
      }

      for (const Reply of Replies.splice(0)) {
        Reply("");
      }
    };

    Replies.push(() => {});
    readline.createInterface({input: Started.stdout!}).on("line", (Said) => {
      const Reply = Replies.shift();

      if (Reply) {
        Reply(Said);
      }
    });
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
    }, 90000);

    Replies.push((Said) => {
      clearTimeout(Timer);
      Resolve(Said);
    });
    Asked.stdin!.write(`${Line}\n`);
  });
}

export async function PressPad(Input: string, Seconds: number): Promise<string> {
  if (process.platform !== "win32") {
    return "The gamepad drives Studio's Controller Emulator through Windows, so it only works on Windows.";
  }

  const Hold = Math.round(Math.min(Math.max(Seconds, 0.05), 5) * 1000);
  const Answer = Input.startsWith("DPad")
    ? await Ask(`dpad\t${Input.slice(4).toLowerCase()}\t${Hold}`)
    : await Ask(`keys\t${Keys[Input].join(",")}\t${Hold}`);

  if (Answer === "OK") {
    return `Held ${Input} on the emulated gamepad for ${Hold / 1000}s and released it. Check the place to see what it did.`;
  }

  if (Answer === "NOSTUDIO") {
    return "No Roblox Studio window is open.";
  }

  if (Answer === "NOPANEL") {
    return "Studio's Controller Emulator panel is not showing. Ask the user to open it (Test tab, Controller Emulator) and leave it docked where it can be seen, then try again.";
  }

  return `The emulated gamepad did not answer${Answer ? `: ${Answer}` : ", so its helper was restarted"}. Try again.`;
}
