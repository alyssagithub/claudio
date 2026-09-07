const Pending = [];
const Waiting = new Map();

let Counter = 0;

export function Request(Kind, Input, Timeout) {
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
    Pending.push({ Id, Kind, Input });

    setTimeout(() => {
      const Index = Pending.findIndex((Job) => Job.Id === Id);

      if (Index >= 0) {
        Pending.splice(Index, 1);
      }

      Give({ error: "Studio did not pick this up. Check the plugin is connected and a place is open." });
    }, Timeout || 60000);
  });
}

export function Take() {
  const Job = Pending.shift();

  return Job ? { id: Job.Id, kind: Job.Kind, input: Job.Input } : null;
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
