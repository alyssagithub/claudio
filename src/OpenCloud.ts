import fs from "node:fs";
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
};

export async function CallOpenCloud(Call: OpenCloudCall): Promise<string> {
  const Key = OpenCloudKey();

  if (!Key) {
    return "No Open Cloud API key is set. Ask the user to paste their key into the chat, on its own or inside a message; Claudio saves it and swaps it for a placeholder before the message reaches you, so you never see it.";
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

  try {
    Text = JSON.stringify(JSON.parse(Text), null, 2);
  } catch {
    Text = Text.trim();
  }

  const Hint = Response.status === 401 || Response.status === 403
    ? "\nThe key was refused for this call. It may lack the permission or the experience this needs, or have expired; the user can add them on the Creator Dashboard or paste a new key."
    : "";

  return `${Method} ${Url.pathname}${Url.search} -> ${Response.status} ${Response.statusText}${Hint}\n${Text.slice(0, MostCallText)}`;
}
