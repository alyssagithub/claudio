const Pending = [];
const Waiting = new Map();

let Counter = 0;

export function Request(Kind, Input, Timeout, Role) {
  return new Promise((Resolve) => {
    const Id = `job-${Counter += 1}-${Math.random().toString(36).slice(2, 8)}`;
    const Give = (Result) => {
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

let CanRun = null;

export function Seen(Role, Able) {
  Heard.set(Role || "edit", Date.now());

  if (Able !== undefined) {
    CanRun = Able;
  }
}

export function Take(Role, Able) {
  const Wanted = Role || "edit";

  Seen(Wanted, Able);

  const At = Pending.findIndex((Job) => Job.Role === Wanted);

  if (At < 0) {
    return null;
  }

  const [Job] = Pending.splice(At, 1);

  return { id: Job.Id, kind: Job.Kind, input: Job.Input };
}

export function Presence() {
  return {
    lastSeen: Heard.get("edit") || 0,
    runtimeSeen: Heard.get("server") || 0,
    canRun: CanRun,
    waiting: Waiting.size,
    queued: Pending.length,
  };
}

export function RuntimeLive() {
  const Last = Heard.get("server") || 0;

  return Date.now() - Last < 6000;
}

export function Deliver(Id, Result) {
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
