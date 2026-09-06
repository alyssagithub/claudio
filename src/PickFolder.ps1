Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class ClaudioFolderPicker
{
    [ComImport, Guid("DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7")]
    private class FileOpenDialog { }

    [ComImport, Guid("42F85136-DB7E-439C-85F1-E4075D135FC8"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IFileDialog
    {
        [PreserveSig] int Show(IntPtr parent);
        void SetFileTypes(uint count, IntPtr types);
        void SetFileTypeIndex(uint index);
        void GetFileTypeIndex(out uint index);
        void Advise(IntPtr events, out uint cookie);
        void Unadvise(uint cookie);
        void SetOptions(uint options);
        void GetOptions(out uint options);
        void SetDefaultFolder(IShellItem item);
        void SetFolder(IShellItem item);
        void GetFolder(out IShellItem item);
        void GetCurrentSelection(out IShellItem item);
        void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string name);
        void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string name);
        void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string title);
        void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string text);
        void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string label);
        void GetResult(out IShellItem item);
        void AddPlace(IShellItem item, int place);
        void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string extension);
        void Close([MarshalAs(UnmanagedType.Error)] int result);
        void SetClientGuid(ref Guid guid);
        void ClearClientData();
        void SetFilter(IntPtr filter);
    }

    [ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IShellItem
    {
        void BindToHandler(IntPtr bc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
        void GetParent(out IShellItem parent);
        void GetDisplayName(uint sigdnName, [MarshalAs(UnmanagedType.LPWStr)] out string name);
        void GetAttributes(uint mask, out uint attributes);
        void Compare(IShellItem psi, uint hint, out int order);
    }

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr param);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr window);

    [DllImport("user32.dll")]
    private static extern IntPtr GetWindow(IntPtr window, uint command);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr window, StringBuilder text, int count);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr window);

    private delegate bool EnumWindowsProc(IntPtr window, IntPtr param);

    // Studio's main window is the visible, ownerless one on the process, and its
    // class tells it apart from the splash and the tooltip windows.
    private static IntPtr FindStudio(uint processId)
    {
        IntPtr found = IntPtr.Zero;

        EnumWindows(delegate(IntPtr window, IntPtr param)
        {
            uint owner;

            GetWindowThreadProcessId(window, out owner);

            if (owner != processId || !IsWindowVisible(window) || GetWindow(window, 4) != IntPtr.Zero)
            {
                return true;
            }

            StringBuilder name = new StringBuilder(256);

            GetClassName(window, name, name.Capacity);

            if (name.ToString().IndexOf("Qt", StringComparison.Ordinal) < 0)
            {
                return true;
            }

            found = window;
            return false;
        }, IntPtr.Zero);

        return found;
    }

    public static string Pick(string title, int processId)
    {
        IntPtr owner = processId > 0 ? FindStudio((uint)processId) : IntPtr.Zero;
        IFileDialog dialog = (IFileDialog)(new FileOpenDialog());

        if (owner != IntPtr.Zero)
        {
            SetForegroundWindow(owner);
        }

        uint options;

        dialog.GetOptions(out options);
        dialog.SetOptions(options | 0x20 | 0x8 | 0x800); // pick folders, file must exist, force filesystem
        dialog.SetTitle(title);

        if (dialog.Show(owner) != 0)
        {
            return "";
        }

        IShellItem item;
        string path;

        dialog.GetResult(out item);
        item.GetDisplayName(0x80058000, out path); // filesys path
        return path;
    }
}
'@

$Studio = Get-Process -Name RobloxStudioBeta, RobloxStudio -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1

$Owner = if ($Studio) { $Studio.Id } else { 0 }

[ClaudioFolderPicker]::Pick("Pick the folder Claude should work in", $Owner)
