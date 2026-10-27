type Job = {
  Id: string;
  Kind: string;
  Input: unknown;
  Role: string;
};

const Pending: Job[] = [];
const Waiting = new Map<string, (Result: unknown) => void>();
const Roles = new Map<string, string>();

let Counter = 0;

export type Owner = { Id: string; Name: () => string };

const Users = new Map<string, { Name: () => string; At: number }>();
const Boots = new Set<string>();
let ReloadedAt = 0;
const Playtest = { By: "", Since: 0, Live: false, Players: 0, Most: 0, StoppedBy: "", StoppedAt: 0, ReplacedBy: "" };

function Ago(At: number): string {
  const Seconds = Math.max(1, Math.round((Date.now() - At) / 1000));

  return Seconds < 120 ? `${Seconds}s ago` : `${Math.round(Seconds / 60)} min ago`;
}

function Notice(Kind: string, Input: unknown, Who?: Owner): string | null {
  const Notes: string[] = [];
  const Action = Input && typeof Input === "object" ? (Input as { action?: unknown }).action : undefined;

  if (Who) {
    const Others = [...Users.entries()].filter(([Id, Used]) => Id !== Who.Id && Date.now() - Used.At < 180000);

    if (Others.length > 0) {
      const Grouped = new Map<string, { Count: number; At: number }>();

      for (const [, Used] of Others) {
        const Name = Used.Name();
        const Held = Grouped.get(Name) || {Count: 0, At: 0};

        Grouped.set(Name, {Count: Held.Count + 1, At: Math.max(Held.At, Used.At)});
      }

      const Listed = [...Grouped.entries()].map(([Name, Held]) => `${Name}${Held.Count > 1 ? ` (${Held.Count} of them, the latest used it ${Ago(Held.At)})` : ` (last used it ${Ago(Held.At)})`}`);

      Notes.push(`${Others.length > 1 ? "Other sessions are" : "Another session is"} driving this Studio too: ${Listed.join("; ")}. Their playtests, plugin reloads and probe scripts can stop or change yours, so if something stops unexpectedly, wait and retry rather than treating it as a bug in the game.`);
    }

    if (Playtest.By === Who.Id && Playtest.Live && (Playtest.StoppedBy !== "" || !RuntimeLive()) && !(Kind === "playtest" && Action === "start")) {
      const Now = Playtest.ReplacedBy !== "" ? ` A different playtest is running now, started by ${Playtest.ReplacedBy}.` : RuntimeLive() ? " A playtest is running now, but not the one you started." : "";

      Notes.push(Playtest.StoppedBy !== ""
        ? `The playtest you started was stopped ${Ago(Playtest.StoppedAt)} by ${Playtest.StoppedBy}, not by you.${Now}`
        : `The playtest you started has not answered for over 6 seconds: it was stopped from outside, by the user in Studio or a plugin reload, or its server is too busy running code to check in. Check with playtest status before relying on it.${Now}`);
      Playtest.By = "";
      Playtest.StoppedBy = "";
      Playtest.ReplacedBy = "";
    }
  }

  if (Playtest.Players > 0 && RuntimeLive() && Date.now() - Playtest.Since > 45000 && typeof Clients === "number" && Clients < Playtest.Players) {
    Notes.push(Playtest.Most > Clients
      ? `Only ${Clients} of the ${Playtest.Players} players asked for are still in the test: a client window closed or crashed since. Results that need every player may be missing some.`
      : `Only ${Clients} of the ${Playtest.Players} players asked for joined the test: a client window failed to load. Results that need every player may be missing some.`);
  }

  if (ReloadedAt > 0 && Date.now() - ReloadedAt < 180000) {
    Notes.push(`Claudio's plugin reloaded ${Ago(ReloadedAt)}, which ends any playtest that was running then.`);
  }

  return Notes.length > 0 ? Notes.join("\n") : null;
}

function Track(Kind: string, Input: unknown, Who?: Owner) {
  if (!Who) {
    return;
  }

  Users.set(Who.Id, {Name: Who.Name, At: Date.now()});

  const Action = Input && typeof Input === "object" ? (Input as { action?: unknown }).action : undefined;

  if (Kind === "playtest" && Action === "start") {
    const Asked = Input && typeof Input === "object" ? Input as { mode?: unknown; players?: unknown } : {};

    if (Playtest.By !== "" && Playtest.By !== Who.Id && RuntimeLive() && Playtest.StoppedBy === "") {
      return;
    }

    if (Playtest.By !== "" && Playtest.By !== Who.Id) {
      Playtest.ReplacedBy = Who.Name();

      return;
    }

    Playtest.By = Who.Id;
    Playtest.StoppedBy = "";
    Playtest.ReplacedBy = "";
    Playtest.Since = Date.now();
    Playtest.Live = false;
    Playtest.Players = Asked.mode === "multiplayer" ? Math.max(1, Number(Asked.players) || 1) : 0;
    Playtest.Most = 0;
  } else if (Kind === "playtest" && Action === "stop") {
    if (Playtest.By !== "" && Playtest.By !== Who.Id) {
      Playtest.StoppedBy = Who.Name();
      Playtest.StoppedAt = Date.now();
    } else {
      Playtest.By = "";
    }
  }
}

export function Booted(Boot: string | null) {
  if (!Boot || Boots.has(Boot)) {
    return;
  }

  if (Boots.size > 0) {
    ReloadedAt = Date.now();
  }

  Boots.add(Boot);
}

export function Request(Kind: string, Input: unknown, Timeout?: number | null, Role?: string | null, Who?: Owner): Promise<unknown> {
  const Note = Kind === "playtest" || Kind === "execute" ? Notice(Kind, Input, Who) : null;

  Track(Kind, Input, Who);

  return Raw(Kind, Input, Timeout, Role).then((Result) => Note && Result && typeof Result === "object" && !Array.isArray(Result) ? {...Result, notice: Note} : Result);
}

function Raw(Kind: string, Input: unknown, Timeout?: number | null, Role?: string | null): Promise<unknown> {
  return new Promise<unknown>((Resolve) => {
    const Id = `job-${Counter += 1}-${Math.random().toString(36).slice(2, 8)}`;
    let Timer: NodeJS.Timeout | null = null;

    if (Pending.length >= 200) {
      Resolve({error: "Studio has 200 jobs waiting already. Check the plugin is connected, then try again."});
      return;
    }

    const Give = (Result: unknown) => {
      if (!Waiting.has(Id)) {
        return;
      }

      Waiting.delete(Id);
      Roles.delete(Id);

      if (Timer) {
        clearTimeout(Timer);
      }

      Resolve(Result);
    };

    Waiting.set(Id, Give);
    Roles.set(Id, Role || "edit");
    Pending.push({
      Id,
      Kind,
      Input,
      Role: Role || "edit",
    });

    Timer = setTimeout(() => {
      const Index = Pending.findIndex((Job) => Job.Id === Id);

      if (Index >= 0) {
        Pending.splice(Index, 1);
        const Last = Heard.get(Role || "edit") || 0;

        Give({error: Date.now() - Last < 180000 && Date.now() - Last > 5000
          ? `Studio did not pick this up: it last checked in ${Math.round((Date.now() - Last) / 1000)}s ago and has been busy since, most likely still running earlier code inside one long call. Try again once that finishes.`
          : "Studio did not pick this up. Check the plugin is connected and a place is open."});

        return;
      }

      Give({error: `Studio took this but did not finish within ${Math.round((Timeout || 60000) / 1000)} seconds. It may still be running, so check the place before trying it again.`});
    }, Timeout || 60000);
  });
}

const Heard = new Map();
const StartedAt = Date.now();

let CanRun: boolean | null = null;
let Clients: number | null = null;
let Ready: number | null = null;
let Settled: number | null = null;
let BridgeVersion: string | null = null;
let BridgeRoot: string | null = null;
let ToolCount: number | null = null;

export function Serving(Version: string, Root: string, Tools: number): void {
  BridgeVersion = Version;
  BridgeRoot = Root;
  ToolCount = Tools;
}

export function Seen(Role?: string | null, Able?: boolean, Attached?: number, Loaded?: number, Games?: number): void {
  if (Role && !/^(edit|server|client(-\d+)?)$/.test(Role)) {
    return;
  }

  Heard.set(Role || "edit", Date.now());

  if (Role === "server" && Playtest.By !== "") {
    Playtest.Live = true;
  }

  if (Role === "server" && typeof Attached === "number") {
    Playtest.Most = Math.max(Playtest.Most, Attached);
  }

  if (Able !== undefined) {
    CanRun = Able;
  }

  if (Attached !== undefined) {
    Clients = Attached;
  }

  if (Loaded !== undefined) {
    Ready = Loaded;
  }

  if (Games !== undefined) {
    Settled = Games;
  }
}

export function Take(Role?: string | null, Able?: boolean, Attached?: number, Loaded?: number, Games?: number) {
  const Wanted = Role || "edit";

  Seen(Wanted, Able, Attached, Loaded, Games);

  const At = Pending.findIndex((Job) => Job.Role === Wanted);

  if (At < 0) {
    return null;
  }

  const [Job] = Pending.splice(At, 1) as [Job];

  return {
    id: Job.Id,
    kind: Job.Kind,
    input: Job.Input,
  };
}

export function Presence() {
  return {
    lastSeen: Heard.get("edit") || 0,
    runtimeSeen: Heard.get("server") || 0,
    canRun: CanRun,
    clients: Clients,
    ready: Ready,
    settled: Settled,
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

export function Deliver(Id: string, Result: unknown, FromPlaytest?: boolean): boolean {
  const Give = Waiting.get(Id);

  if (!Give || (FromPlaytest && Roles.get(Id) === "edit")) {
    return false;
  }

  Give(Result);

  return true;
}

export function Outstanding() {
  return Waiting.size;
}