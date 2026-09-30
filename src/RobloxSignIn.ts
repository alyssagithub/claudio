import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { DefaultPort } from "./Config.js";

const ClientId = "6132914006670630063";
const RedirectUri = `http://localhost:${DefaultPort}/oauth/callback`;
const Scopes = ["game-pass:read", "game-pass:write", "developer-product:read", "developer-product:write", "legacy-universe.badge:manage-and-spend-robux"];
const TokenFile = path.join(os.homedir(), ".claudio", "roblox-signin.json");

type Tokens = {
  access: string;
  refresh: string;
  expiresAt: number;
  scope: string;
};

let Waiting: { State: string; Verifier: string; Finish: (Outcome: string | null) => void } | null = null;

function Read(): Tokens | null {
  try {
    const Saved = JSON.parse(fs.readFileSync(TokenFile, "utf8")) as Tokens;

    return typeof Saved.refresh === "string" ? Saved : null;
  } catch {
    return null;
  }
}

function Save(Given: { access_token: string; refresh_token: string; expires_in: number; scope?: string } | null) {
  if (!Given) {
    fs.rmSync(TokenFile, {force: true});
    return;
  }

  fs.mkdirSync(path.dirname(TokenFile), {recursive: true});
  fs.writeFileSync(TokenFile, JSON.stringify({
    access: Given.access_token,
    refresh: Given.refresh_token,
    expiresAt: Date.now() + Given.expires_in * 1000,
    scope: Given.scope || "",
  } satisfies Tokens), {mode: 0o600});
}

async function Exchange(Fields: Record<string, string>): Promise<string | null> {
  let Answer: Response;

  try {
    Answer = await fetch("https://apis.roblox.com/oauth/v1/token", {
      method: "POST",
      headers: {"content-type": "application/x-www-form-urlencoded"},
      body: new URLSearchParams({client_id: ClientId, ...Fields}),
      signal: AbortSignal.timeout(30000),
    });
  } catch (Trouble) {
    return `Could not reach Roblox to finish signing in: ${(Trouble as Error).message}`;
  }

  const Body = await Answer.json().catch(() => null) as { access_token?: string; refresh_token?: string; expires_in?: number; scope?: string; error?: string; error_description?: string } | null;

  if (!Answer.ok || !Body || !Body.access_token || !Body.refresh_token) {
    return `Roblox refused the sign-in: ${(Body && (Body.error_description || Body.error)) || Answer.status}`;
  }

  Save({access_token: Body.access_token, refresh_token: Body.refresh_token, expires_in: Body.expires_in || 900, scope: Body.scope});

  return null;
}

export function SignedIn(): boolean {
  return Read() !== null;
}

export async function AccessToken(): Promise<string | null> {
  const Saved = Read();

  if (!Saved) {
    return null;
  }

  if (Saved.expiresAt - Date.now() > 60000) {
    return Saved.access;
  }

  const Trouble = await Exchange({grant_type: "refresh_token", refresh_token: Saved.refresh});

  if (Trouble) {
    Save(null);

    return null;
  }

  return (Read() as Tokens).access;
}

export function SignOut() {
  Save(null);
}

export function SignIn(Seconds: number): Promise<string | null> {
  if (Waiting) {
    Waiting.Finish("A newer sign-in was started.");
  }

  const Verifier = crypto.randomBytes(48).toString("base64url");
  const State = crypto.randomBytes(24).toString("base64url");
  const Address = new URL("https://apis.roblox.com/oauth/v1/authorize");

  Address.search = new URLSearchParams({
    client_id: ClientId,
    redirect_uri: RedirectUri,
    response_type: "code",
    scope: Scopes.join(" "),
    state: State,
    code_challenge: crypto.createHash("sha256").update(Verifier).digest("base64url"),
    code_challenge_method: "S256",
  }).toString();

  const [Program, Arguments] = process.platform === "win32"
    ? ["rundll32.exe", ["url.dll,FileProtocolHandler", Address.href]]
    : [process.platform === "darwin" ? "open" : "xdg-open", [Address.href]];

  execFile(Program, Arguments, {windowsHide: true}, () => {});

  return new Promise((Resolve) => {
    const Timer = setTimeout(() => Mine.Finish("The browser sign-in was not finished within the time allowed. Call again to reopen it."), Seconds * 1000);
    const Mine = {
      State,
      Verifier,
      Finish: (Outcome: string | null) => {
        clearTimeout(Timer);

        if (Waiting === Mine) {
          Waiting = null;
        }

        Resolve(Outcome);
      },
    };

    Waiting = Mine;
  });
}

export async function FinishSignIn(Query: URLSearchParams): Promise<string> {
  if (!Waiting || Query.get("state") !== Waiting.State) {
    return "This sign-in link is out of date. Go back to Claude and ask it to sign in again.";
  }

  const Current = Waiting;

  if (Query.get("error")) {
    Current.Finish(`Roblox sign-in was cancelled: ${Query.get("error_description") || Query.get("error")}`);

    return "Sign-in was cancelled. You can close this tab.";
  }

  const Trouble = await Exchange({grant_type: "authorization_code", code: Query.get("code") || "", code_verifier: Current.Verifier, redirect_uri: RedirectUri});

  Current.Finish(Trouble);

  return Trouble ? `${Trouble}. You can close this tab.` : "Signed in to Roblox for Claudio. You can close this tab and go back to Claude.";
}
