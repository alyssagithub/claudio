$ErrorActionPreference = "Stop"

Add-Type -Namespace Claudio -Name Window -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)]
public struct FLASHWINFO { public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout; }
[DllImport("user32.dll")] public static extern bool FlashWindowEx(ref FLASHWINFO pwfi);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
'@

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

if ($env:CLAUDIO_TOAST -ne "0") {
    "toast"
}
