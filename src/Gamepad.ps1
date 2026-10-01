Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
public static class Pad {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr extra);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr handle);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr handle);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr handle, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr handle, out uint process);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr handle, out Rect rect);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr handle, IntPtr context, uint flags);
  [DllImport("user32.dll")] public static extern IntPtr RealChildWindowFromPoint(IntPtr parent, Point point);
  [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr handle, ref Point point);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr handle, uint message, IntPtr wide, IntPtr low);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint kind);
  public delegate bool EnumWindowsProc(IntPtr handle, IntPtr extra);
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }

  public static int[] Find(Bitmap Haystack, Bitmap Needle) {
    var Big = Haystack.LockBits(new Rectangle(0, 0, Haystack.Width, Haystack.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var Small = Needle.LockBits(new Rectangle(0, 0, Needle.Width, Needle.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var A = new byte[Big.Stride * Haystack.Height];
    var B = new byte[Small.Stride * Needle.Height];
    Marshal.Copy(Big.Scan0, A, 0, A.Length);
    Marshal.Copy(Small.Scan0, B, 0, B.Length);
    Haystack.UnlockBits(Big);
    Needle.UnlockBits(Small);
    int Best = int.MaxValue, BestX = -1, BestY = -1;
    int Limit = Needle.Width * Needle.Height * 40;
    int AnchorX = 0, AnchorY = 0, Brightest = -1;
    for (int J = 0; J < Needle.Height; J++) {
      for (int I = 0; I < Needle.Width; I++) {
        int Q = J * Small.Stride + I * 4;
        if (B[Q] + B[Q + 1] + B[Q + 2] > Brightest) { Brightest = B[Q] + B[Q + 1] + B[Q + 2]; AnchorX = I; AnchorY = J; }
      }
    }
    int Anchor = AnchorY * Small.Stride + AnchorX * 4;
    for (int Y = 0; Y <= Haystack.Height - Needle.Height; Y++) {
      for (int X = 0; X <= Haystack.Width - Needle.Width; X++) {
        int First = (Y + AnchorY) * Big.Stride + (X + AnchorX) * 4;
        if (Math.Abs(A[First] - B[Anchor]) + Math.Abs(A[First + 1] - B[Anchor + 1]) + Math.Abs(A[First + 2] - B[Anchor + 2]) > 60) { continue; }
        int Score = 0;
        for (int J = 0; J < Needle.Height && Score < Best && Score < Limit; J++) {
          int Row = (Y + J) * Big.Stride + X * 4;
          int Mine = J * Small.Stride;
          for (int I = 0; I < Needle.Width; I++) {
            int P = Row + I * 4, Q = Mine + I * 4;
            Score += Math.Abs(A[P] - B[Q]) + Math.Abs(A[P + 1] - B[Q + 1]) + Math.Abs(A[P + 2] - B[Q + 2]);
          }
        }
        if (Score < Best && Score < Limit) { Best = Score; BestX = X; BestY = Y; }
      }
    }
    return new int[] { BestX, BestY };
  }
}
"@
$Title = New-Object System.Drawing.Bitmap $env:CLAUDIO_PAD_TITLE
$script:Found = [IntPtr]::Zero
$script:Panel = [IntPtr]::Zero
$script:Known = $null

function Find-Studio {
  $Studio = @(Get-Process | Where-Object { $_.Name -like 'RobloxStudio*' } | ForEach-Object { [uint32]$_.Id })
  $script:Found = [IntPtr]::Zero
  $Callback = [Pad+EnumWindowsProc]{
    param($Handle, $Extra)
    if (-not [Pad]::IsWindowVisible($Handle)) { return $true }
    $Owner = [uint32]0
    [void][Pad]::GetWindowThreadProcessId($Handle, [ref]$Owner)
    if ($Studio -notcontains $Owner) { return $true }
    $Text = New-Object System.Text.StringBuilder 512
    [void][Pad]::GetWindowText($Handle, $Text, 512)
    if ($Text.ToString().EndsWith('Roblox Studio') -and $script:Found -eq [IntPtr]::Zero) { $script:Found = $Handle }
    return $true
  }
  [void][Pad]::EnumWindows($Callback, [IntPtr]::Zero)
}

function Get-Rect($Handle) {
  $Rect = New-Object Pad+Rect
  [void][Pad]::GetWindowRect($Handle, [ref]$Rect)
  return $Rect
}

function Deepest($X, $Y) {
  $Rect = Get-Rect $script:Found
  $Screen = New-Object Pad+Point
  $Screen.X = $Rect.Left + $X
  $Screen.Y = $Rect.Top + $Y
  $Target = $script:Found
  while ($true) {
    $Local = $Screen
    [void][Pad]::ScreenToClient($Target, [ref]$Local)
    $Child = [Pad]::RealChildWindowFromPoint($Target, $Local)
    if ($Child -eq [IntPtr]::Zero -or $Child -eq $Target) { break }
    $Target = $Child
  }
  $Point = $Screen
  [void][Pad]::ScreenToClient($Target, [ref]$Point)
  return @($Target, [IntPtr](($Point.Y -shl 16) -bor ($Point.X -band 0xFFFF)))
}

function Find-Panel {
  if ($script:Panel -ne [IntPtr]::Zero -and [Pad]::IsWindow($script:Panel) -and [Pad]::IsWindowVisible($script:Panel)) {
    $Now = Get-Rect $script:Panel
    if ($script:Known -and $Now.Left -eq $script:Known.Left -and $Now.Top -eq $script:Known.Top -and $Now.Right -eq $script:Known.Right -and $Now.Bottom -eq $script:Known.Bottom) { return $true }
  }
  if ($script:Found -eq [IntPtr]::Zero -or -not [Pad]::IsWindow($script:Found)) { Find-Studio }
  if ($script:Found -eq [IntPtr]::Zero) { return 'NOSTUDIO' }
  $Rect = Get-Rect $script:Found
  $Shot = New-Object System.Drawing.Bitmap ($Rect.Right - $Rect.Left), ($Rect.Bottom - $Rect.Top)
  $Graphics = [System.Drawing.Graphics]::FromImage($Shot)
  $Context = $Graphics.GetHdc()
  [void][Pad]::PrintWindow($script:Found, $Context, 2)
  $Graphics.ReleaseHdc($Context)
  $Graphics.Dispose()
  $At = [Pad]::Find($Shot, $Title)
  $Shot.Dispose()
  if ($At[0] -lt 0) { return 'NOPANEL' }
  $script:Panel = (Deepest ($At[0] + $Title.Width / 2) ($At[1] + 40))[0]
  $script:Known = Get-Rect $script:Panel
  return $true
}

function Send-Pad($Keys, $Dpad, $Hold) {
  $Ready = Find-Panel
  if ($Ready -ne $true) { return $Ready }
  $Rect = Get-Rect $script:Found
  $Inside = $script:Known
  $Left = $Inside.Left - $Rect.Left
  $Top = $Inside.Top - $Rect.Top
  $Width = $Inside.Right - $Inside.Left
  if ($Dpad) {
    $Scale = $Width / 361
    $Reach = 8 * $Scale
    $X = $Left + 0.4224 * $Width + $(switch ($Dpad) { 'left' { -$Reach } 'right' { $Reach } default { 0 } })
    $Y = $Top + 166.5 * $Scale + $(switch ($Dpad) { 'up' { -$Reach } 'down' { $Reach } default { 0 } })
    $Target, $Packed = Deepest ([int]$X) ([int]$Y)
    [void][Pad]::PostMessage($Target, 0x200, [IntPtr]::Zero, $Packed)
    [void][Pad]::PostMessage($Target, 0x201, [IntPtr]1, $Packed)
    Start-Sleep -Milliseconds $Hold
    [void][Pad]::PostMessage($Target, 0x202, [IntPtr]::Zero, $Packed)
    return 'OK'
  }
  $Target, $Packed = Deepest ([int]($Left + 0.48 * $Width)) ($Inside.Bottom - $Rect.Top - 8)
  [void][Pad]::PostMessage($Target, 0x201, [IntPtr]1, $Packed)
  [void][Pad]::PostMessage($Target, 0x202, [IntPtr]::Zero, $Packed)
  Start-Sleep -Milliseconds 100
  foreach ($Key in $Keys) {
    [void][Pad]::PostMessage($Target, 0x100, [IntPtr]$Key, [IntPtr](1 -bor ([Pad]::MapVirtualKey($Key, 0) -shl 16)))
  }
  Start-Sleep -Milliseconds $Hold
  foreach ($Key in $Keys) {
    [void][Pad]::PostMessage($Target, 0x101, [IntPtr]$Key, [IntPtr]([int64]1 -bor ([Pad]::MapVirtualKey($Key, 0) -shl 16) -bor 0xC0000000))
  }
  return 'OK'
}

[Console]::Out.WriteLine('ready')
[Console]::Out.Flush()

while ($null -ne ($Line = [Console]::In.ReadLine())) {
  $Parts = $Line.Split("`t")
  try {
    $Answer = if ($Parts[0] -eq 'dpad') { Send-Pad @() $Parts[1] ([int]$Parts[2]) } else { Send-Pad @($Parts[1] -split ',' | ForEach-Object { [int]$_ }) $null ([int]$Parts[2]) }
  } catch {
    $Answer = "FAILED $($_.Exception.Message)"
  }
  [Console]::Out.WriteLine($Answer)
  [Console]::Out.Flush()
}
