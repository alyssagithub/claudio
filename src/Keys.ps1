$Built = Join-Path $env:USERPROFILE ".claudio\ReturnWatch.dll"

if (-not (Test-Path $Built) -or (Get-Item $Built).LastWriteTime -lt (Get-Item $PSCommandPath).LastWriteTime) {
    $Source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class ReturnWatch {
    private delegate IntPtr Hook(int Code, IntPtr Kind, IntPtr Info);

    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int Id, Hook Handler, IntPtr Module, uint Thread);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr Handle, int Code, IntPtr Kind, IntPtr Info);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int Key);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string Name);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr Window, out uint Owner);

    private static Hook Kept;

    public static void Run() {
        Kept = Handle;
        SetWindowsHookEx(13, Kept, GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName), 0);
        Console.Out.WriteLine("{\"ready\":true}");
        Console.Out.Flush();

        System.Threading.Thread Watch = new System.Threading.Thread(() => {
            while (Console.In.ReadLine() != null) {
            }

            Environment.Exit(0);
        });

        Watch.IsBackground = true;
        Watch.Start();
        Application.Run();
    }

    private static bool StudioInFront() {
        uint Owner;

        GetWindowThreadProcessId(GetForegroundWindow(), out Owner);

        try {
            return Process.GetProcessById((int)Owner).ProcessName.StartsWith("RobloxStudio");
        } catch {
            return false;
        }
    }

    private static IntPtr Handle(int Code, IntPtr Kind, IntPtr Info) {
        if (Code >= 0 && (Kind == (IntPtr)0x0100 || Kind == (IntPtr)0x0104)) {
            int Key = Marshal.ReadInt32(Info);

            bool Control = (GetAsyncKeyState(0x11) & 0x8000) != 0;

            if ((Key == 0x0D || (Key == 0x43 && Control)) && StudioInFront()) {
                bool Shift = (GetAsyncKeyState(0x10) & 0x8000) != 0;

                Console.Out.WriteLine("{\"at\":" + DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() + ",\"shift\":" + (Shift ? "true" : "false") + ",\"key\":\"" + (Key == 0x0D ? "return" : "copy") + "\"}");
                Console.Out.Flush();
            }
        }

        return CallNextHookEx(IntPtr.Zero, Code, Kind, Info);
    }
}
'@

    New-Item -ItemType Directory -Force (Split-Path $Built) | Out-Null
    Add-Type -TypeDefinition $Source -ReferencedAssemblies System.Windows.Forms -OutputAssembly $Built | Out-Null
}

Add-Type -Path $Built
[ReturnWatch]::Run()