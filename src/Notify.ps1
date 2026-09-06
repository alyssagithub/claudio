$ErrorActionPreference = "Stop"

Add-Type -Namespace Claudio -Name Window -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)]
public struct FLASHWINFO { public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout; }
[StructLayout(LayoutKind.Sequential)]
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
[StructLayout(LayoutKind.Sequential)]
public struct POINT { public int X; public int Y; }
[StructLayout(LayoutKind.Sequential)]
public struct SIZE { public int Width; public int Height; }
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct BLENDFUNCTION { public byte BlendOp; public byte BlendFlags; public byte SourceConstantAlpha; public byte AlphaFormat; }
[DllImport("user32.dll")] public static extern bool FlashWindowEx(ref FLASHWINFO pwfi);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
[DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
[DllImport("user32.dll")] public static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref POINT pptDst, ref SIZE psize, IntPtr hdcSrc, ref POINT pprSrc, int crKey, ref BLENDFUNCTION pblend, int dwFlags);
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
[DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
[DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr hDC);
[DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);
[DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr hDC);
[DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr hObject);
[StructLayout(LayoutKind.Sequential)]
public struct ACCENTPOLICY { public int AccentState; public int AccentFlags; public int GradientColor; public int AnimationId; }
[StructLayout(LayoutKind.Sequential)]
public struct WINCOMPATTRDATA { public int Attribute; public IntPtr Data; public int SizeOfData; }
[DllImport("user32.dll")] public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WINCOMPATTRDATA data);
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
'@

if ($env:CLAUDIO_SOUND -eq "1") {
    try {
        $Chime = Join-Path $env:WINDIR "Media\Windows Notify System Generic.wav"

        if (Test-Path $Chime) {
            (New-Object Media.SoundPlayer $Chime).Play()
        } else {
            [System.Media.SystemSounds]::Asterisk.Play()
        }
    } catch {
        try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
    }
}

$Studio = Get-Process -Name RobloxStudioBeta, RobloxStudio -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$Foreground = [Claudio.Window]::GetForegroundWindow()

if (-not $Studio) {
    "quiet"
    exit
}

if ($Foreground -eq $Studio.MainWindowHandle) {
    if ($env:CLAUDIO_ANYWHERE -eq "1" -and $env:CLAUDIO_TOAST -ne "0") {
        "toast"
    } else {
        "quiet"
    }

    exit
}

if ($env:CLAUDIO_NO_FLASH -ne "1") {
    $Flash = New-Object Claudio.Window+FLASHWINFO
    $Flash.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($Flash)
    $Flash.hwnd = $Studio.MainWindowHandle
    $Flash.dwFlags = 15
    $Flash.uCount = 0
    $Flash.dwTimeout = 0
    [Claudio.Window]::FlashWindowEx([ref] $Flash) | Out-Null
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$Screen = [System.Windows.Forms.Screen]::FromHandle($Foreground)
$Bounds = New-Object Claudio.Window+RECT
[Claudio.Window]::GetWindowRect($Foreground, [ref] $Bounds) | Out-Null

$IconPath = $env:CLAUDIO_ICON

if (-not $IconPath -or -not (Test-Path $IconPath)) {
    $IconPath = Join-Path $env:USERPROFILE ".claudio\claudio.png"

    if (-not (Test-Path $IconPath)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $IconPath) | Out-Null

        # Studio running elevated or as another user makes its path unreadable,
        # which is no reason to lose the whole notification.
        try {
            [System.Drawing.Icon]::ExtractAssociatedIcon($Studio.Path).ToBitmap().Save($IconPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } catch {
            $IconPath = $null
        }
    }
}

if (($Bounds.Right - $Bounds.Left) -lt $Screen.Bounds.Width -or ($Bounds.Bottom - $Bounds.Top) -lt $Screen.Bounds.Height) {
    if ($env:CLAUDIO_TOAST -ne "0") {
        "toast"
    }

    exit
}

if ($env:CLAUDIO_BANNER -eq "0") {
    exit
}

$Light = 0
try {
    $Light = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme
} catch {
    $Light = 0
}

if ($Light -eq 1) {
    $Back = [System.Drawing.Color]::FromArgb(1, 249, 249, 249)
    $Tint = 0x99F3F3F3
    $Edge = [System.Drawing.Color]::FromArgb(255, 219, 219, 219)
    $Strong = [System.Drawing.Color]::FromArgb(255, 26, 26, 26)
    $Faint = [System.Drawing.Color]::FromArgb(255, 95, 95, 95)
} else {
    $Back = [System.Drawing.Color]::FromArgb(1, 30, 30, 30)
    $Tint = [int] 0x991E1E1E
    $Edge = [System.Drawing.Color]::FromArgb(255, 77, 77, 77)
    $Strong = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
    $Faint = [System.Drawing.Color]::FromArgb(255, 222, 222, 222)
}

$Installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
$Face = if ($Installed -contains "Segoe UI Variable Text") { "Segoe UI Variable Text" } else { "Segoe UI" }

$Width = 364
$Height = 129
$Work = $Screen.WorkingArea
$Left = $Work.Right - $Width - 16
$Top = $Work.Bottom - $Height - 12
$CloseBox = New-Object System.Drawing.Rectangle(($Width - 46), 8, 36, 30)

$Canvas = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$Draw = [System.Drawing.Graphics]::FromImage($Canvas)
$Draw.SmoothingMode = "AntiAlias"
$Draw.TextRenderingHint = "AntiAliasGridFit"

$Shape = New-Object System.Drawing.Drawing2D.GraphicsPath
$Diameter = 16
$Shape.AddArc(0, 0, $Diameter, $Diameter, 180, 90)
$Shape.AddArc(($Width - $Diameter - 1), 0, $Diameter, $Diameter, 270, 90)
$Shape.AddArc(($Width - $Diameter - 1), ($Height - $Diameter - 1), $Diameter, $Diameter, 0, 90)
$Shape.AddArc(0, ($Height - $Diameter - 1), $Diameter, $Diameter, 90, 90)
$Shape.CloseFigure()

$Fill = New-Object System.Drawing.SolidBrush($Back)
$Draw.FillPath($Fill, $Shape)
$Fill.Dispose()
$Pen = New-Object System.Drawing.Pen($Edge, 1)
$Draw.DrawPath($Pen, $Shape)
$Pen.Dispose()

try {
    $Image = [System.Drawing.Image]::FromFile($IconPath)
    $Draw.DrawImage($Image, (New-Object System.Drawing.Rectangle(16, 49, 48, 48)))
    $Image.Dispose()
} catch {
    $Draw.ResetTransform()
}

$NameFont = New-Object System.Drawing.Font($Face, 9)
$TextFont = New-Object System.Drawing.Font($Face, 10.5)
$StrongBrush = New-Object System.Drawing.SolidBrush($Strong)
$FaintBrush = New-Object System.Drawing.SolidBrush($Faint)

$Typographic = [System.Drawing.StringFormat]::GenericTypographic.Clone()
$Typographic.FormatFlags = 0
$Typographic.Trimming = "EllipsisWord"

$Draw.DrawString("Claudio", $NameFont, $StrongBrush, 38, 14, $Typographic)
$Glyphs = if ($Installed -contains "Segoe Fluent Icons") { "Segoe Fluent Icons" } else { $Face }
$GlyphFont = New-Object System.Drawing.Font($Glyphs, 8)
$More = if ($Glyphs -eq "Segoe Fluent Icons") { [char] 0xE712 } else { [char] 0x22EF }
$Cross = if ($Glyphs -eq "Segoe Fluent Icons") { [char] 0xE711 } else { [char] 0x2715 }

$Draw.DrawString([string] $More, $GlyphFont, $FaintBrush, ($Width - 74), 17, $Typographic)
$Draw.DrawString([string] $Cross, $GlyphFont, $FaintBrush, ($Width - 40), 17, $Typographic)
$Draw.DrawString($env:CLAUDIO_TITLE, $TextFont, $StrongBrush, 79, 50, $Typographic)

$Line = ""
$Row = 0

foreach ($Word in ($env:CLAUDIO_BODY -split " ")) {
    $Candidate = if ($Line -eq "") { $Word } else { "$Line $Word" }

    if ($Draw.MeasureString($Candidate, $TextFont, 10000, $Typographic).Width -le 270 -or $Line -eq "") {
        $Line = $Candidate
        continue
    }

    $Draw.DrawString($Line, $TextFont, $StrongBrush, 79, (70 + 18 * $Row), $Typographic)
    $Line = $Word
    $Row++

    if ($Row -ge 2) {
        break
    }
}

if ($Line -ne "" -and $Row -lt 2) {
    $Draw.DrawString($Line, $TextFont, $StrongBrush, 79, (70 + 18 * $Row), $Typographic)
}

$Typographic.Dispose()
$GlyphFont.Dispose()
$NameFont.Dispose()
$TextFont.Dispose()
$StrongBrush.Dispose()
$FaintBrush.Dispose()
$Draw.Dispose()

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Claudio Banner"
$Form.FormBorderStyle = "None"
$Form.ShowInTaskbar = $false
$Form.TopMost = $true
$Form.StartPosition = "Manual"
$Form.Size = New-Object System.Drawing.Size($Width, $Height)
$Form.Location = New-Object System.Drawing.Point($Left, ($Top + 24))

$Dismissed = $false
$Form.Add_MouseUp({
    param($Sender, $Event)

    if (-not $CloseBox.Contains($Event.Location)) {
        [Claudio.Window]::SetForegroundWindow($Studio.MainWindowHandle) | Out-Null
    }

    $script:Dismissed = $true
})

$Form.CreateControl()
[Claudio.Window]::SetWindowLong($Form.Handle, -20, ([Claudio.Window]::GetWindowLong($Form.Handle, -20) -bor 0x00080000)) | Out-Null

$Rounded = 2
[Claudio.Window]::DwmSetWindowAttribute($Form.Handle, 33, [ref] $Rounded, 4) | Out-Null

$Accent = New-Object Claudio.Window+ACCENTPOLICY
$Accent.AccentState = 4
$Accent.AccentFlags = 2
$Accent.GradientColor = $Tint
$Accent.AnimationId = 0
$AccentSize = [System.Runtime.InteropServices.Marshal]::SizeOf($Accent)
$AccentMemory = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($AccentSize)
[System.Runtime.InteropServices.Marshal]::StructureToPtr($Accent, $AccentMemory, $false)
$Composition = New-Object Claudio.Window+WINCOMPATTRDATA
$Composition.Attribute = 19
$Composition.Data = $AccentMemory
$Composition.SizeOfData = $AccentSize
[Claudio.Window]::SetWindowCompositionAttribute($Form.Handle, [ref] $Composition) | Out-Null
[System.Runtime.InteropServices.Marshal]::FreeHGlobal($AccentMemory)

function Show-Layered {
    param([byte] $Alpha, [int] $PositionTop)

    $ScreenDC = [Claudio.Window]::GetDC([IntPtr]::Zero)
    $MemoryDC = [Claudio.Window]::CreateCompatibleDC($ScreenDC)
    $Handle = $Canvas.GetHbitmap([System.Drawing.Color]::FromArgb(0))
    $Previous = [Claudio.Window]::SelectObject($MemoryDC, $Handle)

    $Position = New-Object Claudio.Window+POINT
    $Position.X = $Left
    $Position.Y = $PositionTop
    $Size = New-Object Claudio.Window+SIZE
    $Size.Width = $Width
    $Size.Height = $Height
    $Source = New-Object Claudio.Window+POINT
    $Blend = New-Object Claudio.Window+BLENDFUNCTION
    $Blend.BlendOp = 0
    $Blend.BlendFlags = 0
    $Blend.SourceConstantAlpha = $Alpha
    $Blend.AlphaFormat = 1

    [Claudio.Window]::UpdateLayeredWindow($Form.Handle, $ScreenDC, [ref] $Position, [ref] $Size, $MemoryDC, [ref] $Source, 0, [ref] $Blend, 2) | Out-Null

    [Claudio.Window]::SelectObject($MemoryDC, $Previous) | Out-Null
    [Claudio.Window]::DeleteObject($Handle) | Out-Null
    [Claudio.Window]::DeleteDC($MemoryDC) | Out-Null
    [Claudio.Window]::ReleaseDC([IntPtr]::Zero, $ScreenDC) | Out-Null
}

Show-Layered 0 ($Top + 24)
[Claudio.Window]::ShowWindow($Form.Handle, 4) | Out-Null

for ($Step = 1; $Step -le 12; $Step++) {
    Show-Layered ([byte] (255 * $Step / 12)) ($Top + [int] (24 * (1 - ($Step / 12))))
    [Claudio.Window]::SetWindowPos($Form.Handle, [IntPtr] (-1), 0, 0, 0, 0, 0x0013) | Out-Null
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 16
}

$Deadline = (Get-Date).AddSeconds(6)

while (-not $Dismissed -and (Get-Date) -lt $Deadline) {
    [Claudio.Window]::SetWindowPos($Form.Handle, [IntPtr] (-1), 0, 0, 0, 0, 0x0013) | Out-Null
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 50
}

for ($Step = 11; $Step -ge 0; $Step--) {
    Show-Layered ([byte] (255 * $Step / 12)) $Top
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 16
}

$Canvas.Dispose()
$Form.Close()
"banner"
