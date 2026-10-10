import fs from "node:fs";
import { execFile } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { MostCallText } from "./Config.js";

const KeyFile = path.join(os.homedir(), ".claudio", "opencloud.json");

export function OpenCloudKey(): string | null {
  try {
    const Saved = JSON.parse(fs.readFileSync(KeyFile, "utf8")) as { key?: unknown };

    return typeof Saved.key === "string" && Saved.key !== "" ? Saved.key : null;
  } catch {
    return null;
  }
}

export function SaveOpenCloudKey(Key: string | null): void {
  if (!Key) {
    fs.rmSync(KeyFile, {force: true});
    return;
  }

  fs.mkdirSync(path.dirname(KeyFile), {recursive: true});
  fs.writeFileSync(KeyFile, JSON.stringify({key: Key, savedAt: new Date().toISOString()}), {mode: 0o600});
}

export type OpenCloudCall = {
  method?: string;
  path: string;
  query?: Record<string, string | number | boolean>;
  body?: unknown;
  contentType?: string;
  form?: Record<string, string | number | boolean>;
  files?: Record<string, string>;
  wait?: boolean;
};

function OperationUrl(Called: URL, Operation: string): URL {
  const Segments = Called.pathname.split("/").filter(Boolean);
  const First = Operation.replace(/^\//, "").split("/")[0];
  const Match = Segments.indexOf(First);
  const Version = Segments.findIndex((Segment) => /^v\d+(beta\d*)?$/.test(Segment));
  const Kept = Match >= 0 ? Segments.slice(0, Match) : Segments.slice(0, Version + 1);

  return new URL(`/${[...Kept, Operation.replace(/^\//, "")].join("/")}`, "https://apis.roblox.com");
}

function ConfirmSpend(Cost: number, Name: string): Promise<boolean> {
  if (process.platform !== "win32") {
    return Promise.resolve(false);
  }

  const Script = "Add-Type -AssemblyName System.Windows.Forms; $Answer = [System.Windows.Forms.MessageBox]::Show($env:CLAUDIO_SPEND_TEXT, 'Claudio: spend Robux?', 'YesNo', 'Warning', 'Button2', 'DefaultDesktopOnly'); if ($Answer -eq 'Yes') { 'yes' } else { 'no' }";

  return new Promise((Resolve) => {
    execFile("powershell", ["-NoProfile", "-NonInteractive", "-Command", Script], {
      timeout: 10 * 60 * 1000,
      env: {...process.env, CLAUDIO_SPEND_TEXT: `Claude wants to create the badge "${Name.slice(0, 80)}", which costs ${Cost} Robux from your account.

Click Yes only if you want to spend ${Cost} Robux. No keeps your Robux and cancels the badge.`},
    }, (Trouble, Output) => Resolve(!Trouble && String(Output).trim() === "yes"));
  });
}

export async function CallOpenCloud(Given: OpenCloudCall): Promise<string> {
  let Call = Given;
  const Key = OpenCloudKey();

  if (!Key) {
    return "No Open Cloud API key is set. Tell the user one of these, so the key never reaches you: open the Claudio panel in Studio and paste it into the Open Cloud API key box in its settings, under Connections, or run `claudio apikey` in a terminal and paste it there. Never ask them to paste it to you in a chat without one of those.";
  }

  let Url: URL;

  try {
    Url = new URL(Call.path, "https://apis.roblox.com");
  } catch {
    return `"${Call.path}" is not a path or address Claudio can call.`;
  }

  if (Url.protocol !== "https:" || Url.hostname !== "apis.roblox.com") {
    return `Open Cloud calls only go to https://apis.roblox.com, so ${Url.host} was not called. The API key is never sent anywhere else.`;
  }

  for (const [Name, Value] of Object.entries(Call.query || {})) {
    Url.searchParams.set(Name, String(Value));
  }

  const Method = (Call.method || "GET").toUpperCase();

  if (Method === "POST" && /^\/legacy-badges\/v1\/universes\/[^/]+\/badges\/?$/.test(Url.pathname)) {
    const Form = {...(Call.form || {})};
    const Cost = Number(Form.expectedCost || 0);

    if (!Number.isFinite(Cost) || Cost < 0) {
      return "expectedCost must be a number of Robux, so the badge was not created.";
    }

    if (Cost > 0 && !(await ConfirmSpend(Cost, String(Form.name || "a badge")))) {
      return `The user did not approve spending ${Cost} Robux, so the badge was not created and nothing was spent. Do not try again unless the user asks for it in their own words.`;
    }

    Form.expectedCost = Cost;
    Call = {...Call, form: Form, body: undefined};
  }

  const Headers: Record<string, string> = {"x-api-key": Key};
  let Body: string | FormData | undefined;

  if ((Call.form || Call.files) && Method !== "GET" && Method !== "HEAD") {
    const Form = new FormData();

    for (const [Name, Value] of Object.entries(Call.form || {})) {
      Form.append(Name, String(Value));
    }

    for (const [Name, File] of Object.entries(Call.files || {})) {
      try {
        Form.append(Name, new Blob([fs.readFileSync(File)]), path.basename(File));
      } catch (Trouble) {
        return `Could not read ${File} to upload: ${(Trouble as Error).message}`;
      }
    }

    Body = Form;
  } else if (Call.body !== undefined && Method !== "GET" && Method !== "HEAD") {
    Body = typeof Call.body === "string" ? Call.body : JSON.stringify(Call.body);
    Headers["content-type"] = Call.contentType || (typeof Call.body === "string" ? "text/plain" : "application/json");
  }

  let Response: globalThis.Response;

  try {
    Response = await fetch(Url, {
      method: Method,
      headers: Headers,
      body: Body,
      signal: AbortSignal.timeout(60000),
    });
  } catch (Trouble) {
    return `The request to ${Url.pathname} did not complete: ${(Trouble as Error).message}`;
  }

  let Text = await Response.text();
  let Waited = "";

  try {
    let Parsed = JSON.parse(Text);
    const Began = Date.now();

    while (Call.wait && Response.ok && Parsed && typeof Parsed.path === "string" && Parsed.done === false && Date.now() - Began < 120000) {
      const Polled = OperationUrl(Url, Parsed.path);

      await new Promise((Resolve) => setTimeout(Resolve, Math.min(5000, 1000 + (Date.now() - Began) / 4)));

      const Checked = await fetch(Polled, {
        headers: {"x-api-key": Key},
        signal: AbortSignal.timeout(60000),
      });

      Parsed = JSON.parse(await Checked.text());
      Waited = `\nWaited ${Math.round((Date.now() - Began) / 1000)}s for the operation, polling GET ${Polled.pathname} -> ${Checked.status} ${Checked.statusText}${Parsed && Parsed.done === false ? ", and it was still not done after two minutes; poll that path again later" : ""}.`;

      if (!Checked.ok) {
        break;
      }
    }

    Text = JSON.stringify(Parsed, null, 2);
  } catch {
    Text = Text.trim();
  }

  let Hint = "";

  if (Response.status === 400 && /legacy-badges/.test(Url.pathname) && /cost/i.test(Text)) {
    Hint = "\nRoblox would charge Robux for this badge, most likely because today's free badges are used up, so it was not created and nothing was spent. Tell the user the cost and ask whether they want to pay it. Only if they clearly say yes, call again with expectedCost set to that amount; Claudio then shows them a Windows dialog to approve the exact amount, and nothing is spent unless they click Yes there.";
  }

  if (Response.status === 401 || Response.status === 403) {
    const Listed = await ScopesFor(Method, Url.pathname);
    const Writing = Method !== "GET" && Method !== "HEAD";
    const Matching = Listed.filter((Scope) => Writing ? !/:read$/.test(Scope) : /:read$/.test(Scope));
    const Needed = Matching.length > 0 ? Matching : Listed;
    const Said = (Text.match(/"message"\s*:\s*"([^"]+)"/) || [])[1] || Text.trim().slice(0, 200);

    Hint = `
Roblox said: "${Said}".`;

    if (/not authenticated|invalid api key|unauthorized/i.test(Said)) {
      Hint += " That usually means Roblox did not accept the key itself for this experience, not a missing permission: check the key has not expired, that this experience is in the key's list of experiences, and that any IP restriction on the key allows this computer.";
    }

    Hint += Needed.length > 0
      ? `\nThe key was refused. Tell the user this call needs the ${Needed.join(" or ")} permission${Needed.length === 1 ? "" : "s"}: on the Creator Dashboard, open their API key, add ${Needed.length === 1 ? "it" : "one of them"}, and make sure this experience is in the key's list, then try again.`
      : "\nThe key was refused for this call. It may lack the permission or the experience this needs, or have expired; the user can add them on the Creator Dashboard or paste a new key.";
  }

  return `${Method} ${Url.pathname}${Url.search} -> ${Response.status} ${Response.statusText}${Hint}${Waited}\n${Text.slice(0, MostCallText)}`;
}

export function AskForKey(): Promise<void> {
  return new Promise((Resolve) => {
    const Input = process.stdin;
    let Typed = "";

    process.stdout.write("Paste your Open Cloud API key and press Enter. It is not shown. Type clear to remove the saved key: ");
    Input.setRawMode?.(true);
    Input.resume();
    Input.setEncoding("utf8");

    const Read = (Chunk: string) => {
      for (const Character of Chunk) {
        if (Character === "\u0003") {
          process.stdout.write("\nCancelled.\n");
          process.exit(1);
        }

        if (Character !== "\r" && Character !== "\n") {
          Typed = Character === "\u0008" || Character === "\u007f" ? Typed.slice(0, -1) : Typed + Character;

          continue;
        }

        Input.setRawMode?.(false);
        Input.pause();
        Input.off("data", Read);

        const Key = Typed.trim();

        SaveOpenCloudKey(Key === "" || Key.toLowerCase() === "clear" ? null : Key);
        process.stdout.write(Key === "" || Key.toLowerCase() === "clear" ? "\nRemoved the saved key.\n" : "\nSaved. Claude can now use it through Claudio's opencloud tool without seeing it.\n");
        Resolve();

        return;
      }
    };

    Input.on("data", Read);
  });
}

const SpecFile = path.join(os.homedir(), ".claudio", "opencloud-scopes.json");

type ScopeRoute = { method: string; pattern: string; scopes: string[] };

async function ScopeRoutes(): Promise<ScopeRoute[]> {
  try {
    const Cached = JSON.parse(fs.readFileSync(SpecFile, "utf8")) as { at: number; routes: ScopeRoute[] };

    if (Date.now() - Cached.at < 7 * 24 * 60 * 60 * 1000) {
      return Cached.routes;
    }
  } catch {
    null;
  }

  try {
    const Spec = await (await fetch("https://create.roblox.com/docs/cloud/openapi.json", {signal: AbortSignal.timeout(20000)})).json() as { paths: Record<string, Record<string, { "x-roblox-scopes"?: { name: string }[]; security?: Record<string, string[]>[] }>> };
    const Routes: ScopeRoute[] = [];

    for (const [Template, Methods] of Object.entries(Spec.paths || {})) {
      for (const [Method, Operation] of Object.entries(Methods)) {
        const Named = (Operation["x-roblox-scopes"] || []).map((Scope) => Scope.name);
        const Secured = (Operation.security || []).flatMap((Entry) => Object.values(Entry).flat());
        const Scopes = [...new Set([...Named, ...Secured])].filter((Scope) => Scope.includes(":"));

        if (Scopes.length > 0) {
          Routes.push({method: Method.toUpperCase(), pattern: `^${Template.replace(/[.*+?^$()|[\]\]/g, "\$&").replace(/\?\{[^}]+\?\}/g, "[^/]+").replace(/\{[^}]+\}/g, "[^/]+")}$`, scopes: Scopes});
        }
      }
    }

    fs.mkdirSync(path.dirname(SpecFile), {recursive: true});
    fs.writeFileSync(SpecFile, JSON.stringify({at: Date.now(), routes: Routes}));

    return Routes;
  } catch {
    return [];
  }
}

export async function ScopesFor(Method: string, Pathname: string): Promise<string[]> {
  const Routes = await ScopeRoutes();
  const Found = Routes.find((Route) => Route.method === Method && new RegExp(Route.pattern).test(Pathname));

  return Found ? Found.scopes : [];
}
