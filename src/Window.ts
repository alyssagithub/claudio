import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { PNG } from "pngjs";

type CropResult = {
  error?: string;
  data?: string;
  width?: number;
  height?: number;
  x?: number;
  y?: number;
};

type WindowShot = {
  error?: string;
  data?: string;
  width?: number;
  height?: number;
  title?: string;
};

type CropBox = {
  x?: number;
  y?: number;
  width?: number;
  height?: number;
};

function Colour(Image: PNG, X: number, Y: number): number[] {
  const At = (Image.width * Y + X) * 4;

  return [Image.data[At], Image.data[At + 1], Image.data[At + 2]];
}

function Same(Image: PNG, X: number, Y: number, Wanted: number[]): boolean {
  const [R, G, B] = Colour(Image, X, Y);

  return R === Wanted[0] && G === Wanted[1] && B === Wanted[2];
}

export function CropToMarker(Data: string, Width: number, Height: number): CropResult {
  const Image = PNG.sync.read(Buffer.from(Data, "base64"));

  for (let Y = 0; Y < Image.height - 8; Y += 1) {
    for (let X = 0; X < Image.width - 16; X += 1) {
      if (!Same(Image, X, Y, [255, 0, 254]) || !Same(Image, X + 8, Y, [1, 255, 254]) || !Same(Image, X + 7, Y + 7, [255, 0, 254]) || !Same(Image, X + 15, Y + 7, [1, 255, 254])) {
        continue;
      }

      const Wide = Math.min(Width, Image.width - X);
      const Tall = Math.min(Height, Image.height - Y);
      const Out = new PNG({
        width: Wide,
        height: Tall,
      });

      PNG.bitblt(Image, Out, X, Y, Wide, Tall, 0, 0);

      const Under = Colour(Image, X, Math.min(Y + 8, Image.height - 1));

      for (let Row = 0; Row < Math.min(8, Tall); Row += 1) {
        for (let Column = 0; Column < Math.min(16, Wide); Column += 1) {
          const At = (Wide * Row + Column) * 4;

          Out.data[At] = Under[0];
          Out.data[At + 1] = Under[1];
          Out.data[At + 2] = Under[2];
        }
      }

      return {
        data: PNG.sync.write(Out).toString("base64"),
        width: Wide,
        height: Tall,
        x: X,
        y: Y,
      };
    }
  }

  return {error: "The panel is open but not visible in the Studio window, so it could not be found in the capture. It may be collapsed behind another tab, or floated onto another screen; give its title as window instead."};
}

const Script = `
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Shot {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr extra);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr handle);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr handle, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr handle, out uint process);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr handle, out Rect rect);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr handle, IntPtr context, uint flags);
  public delegate bool EnumWindowsProc(IntPtr handle, IntPtr extra);
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
}
"@
$Wanted = $env:CLAUDIO_WINDOW_TITLE
$Studio = @(Get-Process | Where-Object { $_.Name -like 'RobloxStudio*' } | ForEach-Object { [uint32]$_.Id })
$Found = [IntPtr]::Zero
$Titles = New-Object System.Collections.Generic.List[string]
$Callback = [Shot+EnumWindowsProc]{
  param($Handle, $Extra)
  if (-not [Shot]::IsWindowVisible($Handle)) { return $true }
  $Owner = [uint32]0
  [void][Shot]::GetWindowThreadProcessId($Handle, [ref]$Owner)
  if ($Studio -notcontains $Owner) { return $true }
  $Text = New-Object System.Text.StringBuilder 512
  [void][Shot]::GetWindowText($Handle, $Text, 512)
  $Title = $Text.ToString()
  if ($Title.Length -eq 0) { return $true }
  $Titles.Add($Title)
  $Matches = if ($Wanted) { $Title.ToLower().Contains($Wanted.ToLower()) } else { $Title.EndsWith('Roblox Studio') }
  if ($Matches -and $script:Found -eq [IntPtr]::Zero) { $script:Found = $Handle }
  return $true
}
[void][Shot]::EnumWindows($Callback, [IntPtr]::Zero)
if ($Found -eq [IntPtr]::Zero) {
  Write-Output ('NONE|' + ($Titles -join '|'))
  exit 0
}
$Rect = New-Object Shot+Rect
[void][Shot]::GetWindowRect($Found, [ref]$Rect)
$Width = $Rect.Right - $Rect.Left
$Height = $Rect.Bottom - $Rect.Top
$Bitmap = New-Object System.Drawing.Bitmap $Width, $Height
$Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
$Context = $Graphics.GetHdc()
[void][Shot]::PrintWindow($Found, $Context, 2)
$Graphics.ReleaseHdc($Context)
$Graphics.Dispose()
$X = [int]$env:CLAUDIO_CROP_X; $Y = [int]$env:CLAUDIO_CROP_Y; $W = [int]$env:CLAUDIO_CROP_W; $H = [int]$env:CLAUDIO_CROP_H
if ($W -gt 0 -and $H -gt 0) {
  $X = [Math]::Max(0, [Math]::Min($X, $Width - 1)); $Y = [Math]::Max(0, [Math]::Min($Y, $Height - 1))
  $W = [Math]::Min($W, $Width - $X); $H = [Math]::Min($H, $Height - $Y)
  $Cropped = $Bitmap.Clone((New-Object System.Drawing.Rectangle $X, $Y, $W, $H), $Bitmap.PixelFormat)
  $Bitmap.Dispose()
  $Bitmap = $Cropped
}
$Bitmap.Save($env:CLAUDIO_SHOT_FILE, [System.Drawing.Imaging.ImageFormat]::Png)
$Text = New-Object System.Text.StringBuilder 512
[void][Shot]::GetWindowText($Found, $Text, 512)
Write-Output ('OK|' + $Bitmap.Width + '|' + $Bitmap.Height + '|' + $Text.ToString())
$Bitmap.Dispose()
`;

export function CaptureWindow(Title: string | null | undefined, Crop: CropBox): Promise<WindowShot> {
  if (process.platform !== "win32") {
    return Promise.resolve({error: "Capturing the Studio window only works on Windows, because it reads the window through Win32. Use the viewport capture instead."});
  }

  const File = path.join(os.tmpdir(), `claudio-window-${process.pid}-${Date.now()}.png`);

  return new Promise<WindowShot>((Resolve) => {
    execFile("powershell", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", Script], {
      timeout: 20000,
      windowsHide: true,
      maxBuffer: 4 * 1024 * 1024,
      env: {
        ...process.env,
        CLAUDIO_WINDOW_TITLE: Title || "",
        CLAUDIO_SHOT_FILE: File,
        CLAUDIO_CROP_X: String(Crop.x || 0),
        CLAUDIO_CROP_Y: String(Crop.y || 0),
        CLAUDIO_CROP_W: String(Crop.width || 0),
        CLAUDIO_CROP_H: String(Crop.height || 0),
      },
    }, (Trouble, Output, Errors) => {
      const Line = String(Output || "").trim().split(/\r?\n/).pop() || "";

      if (Trouble || !Line.startsWith("OK|")) {
        if (Line.startsWith("NONE|")) {
          const Titles = Line.slice(5).split("|").filter(Boolean);

          Resolve({error: Title ? `No Studio window has "${Title}" in its title. Open ones: ${Titles.join(", ") || "none"}.` : "No Roblox Studio window is open."});
          return;
        }

        Resolve({error: `Could not capture the Studio window: ${String(Errors || Trouble && Trouble.message || Line).trim().slice(0, 300)}`});
        return;
      }

      const [, Width, Height, Named] = Line.split("|");

      let Data: string;

      try {
        Data = fs.readFileSync(File).toString("base64");
        fs.unlinkSync(File);
      } catch (Error) {
        Resolve({error: `The window capture was taken but could not be read back: ${(Error as NodeJS.ErrnoException).message}`});
        return;
      }

      Resolve({
        data: Data,
        width: Number(Width),
        height: Number(Height),
        title: Named,
      });
    });
  });
}