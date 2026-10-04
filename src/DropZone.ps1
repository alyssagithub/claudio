Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public class DropZone : Form {
  [DllImport("user32.dll")] static extern short GetAsyncKeyState(int Key);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr Window, out uint Owner);
  [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point Where);
  [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr Window, uint Kind);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr Window, out Box Rect);
  [StructLayout(LayoutKind.Sequential)] struct Box { public int Left, Top, Right, Bottom; }

  static readonly string[] StudioTypes = { ".rbxm", ".rbxmx", ".rbxl", ".rbxlx", ".fbx", ".obj", ".gltf", ".glb", ".lua", ".luau" };

  public static readonly object Gate = new object();
  public static Rectangle Area = Rectangle.Empty;
  public static Point Origin = Point.Empty;
  public static bool Known = false;
  Label Hint;

  protected override bool ShowWithoutActivation { get { return true; } }

  protected override CreateParams CreateParams {
    get {
      CreateParams Made = base.CreateParams;
      Made.ExStyle |= 0x08000000 | 0x00000080 | 0x00000008;
      return Made;
    }
  }

  public DropZone() {
    FormBorderStyle = FormBorderStyle.None;
    ShowInTaskbar = false;
    TopMost = true;
    StartPosition = FormStartPosition.Manual;
    BackColor = Color.FromArgb(30, 30, 34);
    Opacity = 0.7;
    AllowDrop = true;
    Hint = new Label();
    Hint.Dock = DockStyle.Fill;
    Hint.TextAlign = ContentAlignment.MiddleCenter;
    Hint.ForeColor = Color.White;
    Hint.Font = new Font("Segoe UI", 11);
    Hint.Text = "Drop files to attach them to Claudio";
    Hint.AllowDrop = true;
    Controls.Add(Hint);

    DragEventHandler Enter = (Sender, Event) => {
      string[] Paths = Event.Data.GetData(DataFormats.FileDrop) as string[];

      if (Paths == null || Paths.Length == 0) {
        Event.Effect = DragDropEffects.None;
        Hide();
        return;
      }

      bool ForStudio = false;

      foreach (string Given in Paths) {
        if (Array.IndexOf(StudioTypes, System.IO.Path.GetExtension(Given).ToLowerInvariant()) >= 0) {
          ForStudio = true;
        }
      }

      if (ForStudio) {
        Rectangle Panel = PanelArea();

        if (Panel.Width == 0) {
          Event.Effect = DragDropEffects.None;
          Hide();
          return;
        }

        Bounds = Panel;
        Hint.Text = "Drop here to attach to Claudio";
      }

      Event.Effect = DragDropEffects.Copy;
    };
    DragEventHandler Dropped = (Sender, Event) => {
      string[] Paths = Event.Data.GetData(DataFormats.FileDrop) as string[];

      if (Paths != null && Paths.Length > 0) {
        Console.Out.WriteLine("drop\t" + String.Join("\t", Paths));
        Console.Out.Flush();
      }

      Hide();
    };

    DragEnter += Enter;
    Hint.DragEnter += Enter;
    DragDrop += Dropped;
    Hint.DragDrop += Dropped;

    System.Windows.Forms.Timer Watch = new System.Windows.Forms.Timer();
    Watch.Interval = 60;
    Watch.Tick += (Sender, Event) => Check();
    Watch.Start();
  }

  Rectangle PanelArea() {
    lock (Gate) {
      return Known ? new Rectangle(Origin.X + Area.X, Origin.Y + Area.Y, Area.Width, Area.Height) : Rectangle.Empty;
    }
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

  bool StudioInFront() {
    uint Owner;

    GetWindowThreadProcessId(GetForegroundWindow(), out Owner);

    try {
      return Process.GetProcessById((int)Owner).ProcessName.StartsWith("RobloxStudio");
    } catch {
      return false;
    }
  }

  bool WasHeld = false;
  bool PressedOutside = false;

  void Check() {
    bool Held = (GetAsyncKeyState(0x01) & 0x8000) != 0;

    if (Held && !WasHeld) {
      PressedOutside = !IsStudio(GetAncestor(WindowFromPoint(Cursor.Position), 2));
    }

    WasHeld = Held;

    if (Visible) {
      if (!Held) {
        Hide();
      }

      return;
    }

    if (!Held || !PressedOutside || StudioInFront()) {
      return;
    }

    IntPtr Under = GetAncestor(WindowFromPoint(Cursor.Position), 2);

    if (Under == IntPtr.Zero || !IsStudio(Under)) {
      return;
    }

    Box Whole;

    GetWindowRect(Under, out Whole);
    Bounds = new Rectangle(Whole.Left, Whole.Top, Whole.Right - Whole.Left, Whole.Bottom - Whole.Top);
    Hint.Text = "Drop files anywhere to attach them to Claudio";
    Show();
  }

  public static void Begin() {
    Thread Reading = new Thread(Listen);

    Reading.IsBackground = true;
    Reading.Start();
  }

  static void Listen() {
    string Line;

    while ((Line = Console.In.ReadLine()) != null) {
      string[] Parts = Line.Split(' ');

      lock (Gate) {
        if (Parts[0] == "off") {
          Known = false;
        } else if (Parts[0] == "rel" && Parts.Length == 5) {
          Point Now = Cursor.Position;

          Origin = new Point(Now.X - int.Parse(Parts[1]), Now.Y - int.Parse(Parts[2]));
          Area = new Rectangle(0, 0, int.Parse(Parts[3]), int.Parse(Parts[4]));
          Known = true;
        }
      }
    }

    Environment.Exit(0);
  }
}
"@
[DropZone]::Begin()
$Zone = New-Object DropZone
$null = $Zone.Handle
[Console]::Out.WriteLine('ready')
[Console]::Out.Flush()
[System.Windows.Forms.Application]::Run()
