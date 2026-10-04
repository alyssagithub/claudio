Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public class Outline : Form {
  public string Words = "";

  protected override bool ShowWithoutActivation { get { return true; } }

  protected override CreateParams CreateParams {
    get {
      CreateParams Made = base.CreateParams;
      Made.ExStyle |= 0x08000000 | 0x00000080 | 0x00000008;
      return Made;
    }
  }

  public Outline() {
    FormBorderStyle = FormBorderStyle.None;
    ShowInTaskbar = false;
    TopMost = true;
    StartPosition = FormStartPosition.Manual;
    BackColor = Color.Magenta;
    TransparencyKey = Color.Magenta;
    AllowDrop = true;
    DoubleBuffered = true;
  }

  protected override void OnPaint(PaintEventArgs Event) {
    Graphics Canvas = Event.Graphics;
    Color Accent = Color.FromArgb(51, 95, 255);

    using (Pen Line = new Pen(Accent, 3)) {
      Canvas.DrawRectangle(Line, 1, 1, Width - 3, Height - 3);
    }

    using (Font Type = new Font("Segoe UI Semibold", 10)) {
      Size Measured = TextRenderer.MeasureText(Words, Type);
      Rectangle Pill = new Rectangle((Width - Measured.Width - 28) / 2, Height - Measured.Height - 40, Measured.Width + 28, Measured.Height + 14);

      using (SolidBrush Fill = new SolidBrush(Accent)) {
        Canvas.FillRectangle(Fill, Pill);
      }

      TextRenderer.DrawText(Canvas, Words, Type, Pill, Color.White, Accent, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
    }
  }
}

public class DropZone : Form {
  [DllImport("user32.dll")] static extern short GetAsyncKeyState(int Key);
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
  Outline Ring = new Outline();

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
    BackColor = Color.Black;
    Opacity = 0.01;
    AllowDrop = true;

    DragEventHandler Enter = (Sender, Event) => {
      string[] Paths = Event.Data.GetData(DataFormats.FileDrop) as string[];

      if (Paths == null || Paths.Length == 0) {
        Event.Effect = DragDropEffects.None;
        Hide();
        return;
      }

      bool ForStudio = false;

      Console.Out.WriteLine("note\tdrag entered with " + Paths.Length + " file(s), first " + System.IO.Path.GetExtension(Paths[0]));
      Console.Out.Flush();

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

        Place(Panel, "Drop here to attach to Claudio");
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
    Ring.DragEnter += Enter;
    DragDrop += Dropped;
    Ring.DragDrop += Dropped;
    VisibleChanged += (Sender, Event) => {
      if (Visible) {
        Ring.Show();
      } else {
        Ring.Hide();
      }
    };

    System.Windows.Forms.Timer Watch = new System.Windows.Forms.Timer();
    Watch.Interval = 60;
    Watch.Tick += (Sender, Event) => Check();
    Watch.Start();
  }

  void Place(Rectangle Where, string Words) {
    Bounds = Where;
    Ring.Bounds = Where;
    Ring.Words = Words;
    Ring.Invalidate();
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

    if (!Held || !PressedOutside) {
      return;
    }

    IntPtr Under = GetAncestor(WindowFromPoint(Cursor.Position), 2);

    if (Under == IntPtr.Zero || !IsStudio(Under)) {
      return;
    }

    Box Whole;

    GetWindowRect(Under, out Whole);
    Place(new Rectangle(Whole.Left, Whole.Top, Whole.Right - Whole.Left, Whole.Bottom - Whole.Top), "Drop to attach to Claudio");
    Show();
    Console.Out.WriteLine("note\tshown over Studio at " + Bounds.ToString());
    Console.Out.Flush();
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
