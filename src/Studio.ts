type Job = {
  Id: string;
  Kind: string;
  Input: unknown;
  Role: string;
};

const Pending: Job[] = [];
const Waiting = new Map<string, (Result: unknown) => void>();

let Counter = 0;

export function Request(Kind: string, Input: unknown, Timeout?: number | null, Role?: string | null): Promise<unknown> {
  return new Promise<unknown>((Resolve) => {
    const Id = `job-${Counter += 1}-${Math.random().toString(36).slice(2, 8)}`;
    const Give = (Result: unknown) => {
      if (!Waiting.has(Id)) {
        return;
      }

      Waiting.delete(Id);
      Resolve(Result);
    };

    Waiting.set(Id, Give);
    Pending.push({ Id, Kind, Input, Role: Role || "edit" });

    setTimeout(() => {
      const Index = Pending.findIndex((Job) => Job.Id === Id);

      if (Index >= 0) {
        Pending.splice(Index, 1);
      }

      Give({ error: "Studio did not pick this up. Check the plugin is connected and a place is open." });
    }, Timeout || 60000);
  });
}

const Heard = new Map();
const StartedAt = Date.now();

let CanRun: boolean | null = null;
let Clients: number | null = null;
let PluginVersion: string | null = null;
let BridgeVersion: string | null = null;
let BridgeRoot: string | null = null;
let ToolCount: number | null = null;

export function Serving(Version: string, Root: string, Tools: number): void {
  BridgeVersion = Version;
  BridgeRoot = Root;
  ToolCount = Tools;
}

export function Seen(Role?: string | null, Able?: boolean, Attached?: number, Plugin?: string): void {
  Heard.set(Role || "edit", Date.now());

  if (Able !== undefined) {
    CanRun = Able;
  }

  if (Attached !== undefined) {
    Clients = Attached;
  }

  if (Plugin !== undefined) {
    PluginVersion = Plugin;
  }
}

export function Take(Role?: string | null, Able?: boolean, Attached?: number, Plugin?: string) {
  const Wanted = Role || "edit";

  Seen(Wanted, Able, Attached, Plugin);

  const At = Pending.findIndex((Job) => Job.Role === Wanted);

  if (At < 0) {
    return null;
  }

  const [Job] = Pending.splice(At, 1) as [Job];

  return { id: Job.Id, kind: Job.Kind, input: Job.Input };
}

export function Presence() {
  return {
    lastSeen: Heard.get("edit") || 0,
    runtimeSeen: Heard.get("server") || 0,
    canRun: CanRun,
    clients: Clients,
    plugin: PluginVersion,
    bridge: BridgeVersion,
    from: BridgeRoot,
    tools: ToolCount,
    upSince: StartedAt,
    peers: [...Heard.entries()].filter(([, At]) => Date.now() - At < 8000).map(([Role]) => Role),
    waiting: Waiting.size,
    queued: Pending.length,
  };
}

export function RuntimeLive() {
  const Last = Heard.get("server") || 0;

  return Date.now() - Last < 6000;
}

export function Deliver(Id: string, Result: unknown): boolean {
  const Give = Waiting.get(Id);

  if (!Give) {
    return false;
  }

  Give(Result);

  return true;
}

export function Outstanding() {
  return Waiting.size;
}