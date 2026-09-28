$ErrorActionPreference = "Stop"

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public class StudioFlashStopper : NativeWindow {
    [StructLayout(LayoutKind.Sequential)]
    struct FLASHWINFO { public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout; }

    [DllImport("user32.dll")] static extern bool FlashWindowEx(ref FLASHWINFO Info);
    [DllImport("user32.dll")] static extern bool RegisterShellHookWindow(IntPtr Window);
    [DllImport("user32.dll")] static extern bool DeregisterShellHookWindow(IntPtr Window);
    [DllImport("user32.dll")] static extern uint RegisterWindowMessage(string Name);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr Window, out uint Owner);

    readonly uint ShellMessage;
    public int Stopped;
    public static volatile bool Released;

    public static void WatchInput() {
        Thread Reader = new Thread(() => {
            Console.In.ReadLine();
            Released = true;
        });

        Reader.IsBackground = true;
        Reader.Start();
    }

    public StudioFlashStopper() {
        CreateHandle(new CreateParams());
        ShellMessage = RegisterWindowMessage("SHELLHOOK");
        RegisterShellHookWindow(Handle);
    }

    static bool IsStudio(IntPtr Window) {
        uint Owner;

        GetWindowThreadProcessId(Window, out Owner);

        try {
            return Process.GetProcessById((int)Owner).ProcessName.StartsWith("RobloxStudio");
        } catch {
            return false;
        }
    }

    protected override void WndProc(ref Message Received) {
        if (Received.Msg == ShellMessage && (int)Received.WParam == 0x8006 && IsStudio(Received.LParam)) {
            FLASHWINFO Info = new FLASHWINFO();

            Info.cbSize = (uint)Marshal.SizeOf(Info);
            Info.hwnd = Received.LParam;
            FlashWindowEx(ref Info);
            Stopped += 1;
        }

        base.WndProc(ref Received);
    }

    public void Stop() {
        DeregisterShellHookWindow(Handle);
        DestroyHandle();
    }
}
'@

$Stopper = New-Object StudioFlashStopper

try {
    [Console]::Out.WriteLine("quiet")
    [Console]::Out.Flush()

    $Until = (Get-Date).AddSeconds([double]$env:CLAUDIO_QUIET_SECONDS)
    $Released = $null

    [StudioFlashStopper]::WatchInput()

    while ((Get-Date) -lt $Until -and (-not $Released -or (Get-Date) -lt $Released)) {
        if (-not $Released -and [StudioFlashStopper]::Released) {
            $Released = (Get-Date).AddSeconds(3)
        }

        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 20
    }
} finally {
    $Stopper.Stop()
}

[Console]::Out.WriteLine("restored, stopped $($Stopper.Stopped) Studio flashes")
