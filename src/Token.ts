import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { TokenFile } from "./Config.js";
import { WritePluginSetting } from "./PluginSettings.js";

let Current: string | null = null;

function Remember(Value: string): boolean {
  try {
    fs.mkdirSync(path.dirname(TokenFile), { recursive: true });
    fs.writeFileSync(TokenFile, JSON.stringify({ token: Value }, null, 2), { mode: 0o600 });

    return true;
  } catch (Error) {
    console.error(`Could not save the bridge key to ${TokenFile}: ${(Error as NodeJS.ErrnoException).message}`);
    console.error("A new key will be made every time the bridge starts, and Studio will have to be told each time.");

    return false;
  }
}

function Stored(): string | null {
  try {
    const Saved = (JSON.parse(fs.readFileSync(TokenFile, "utf8").replace(/^﻿/, "")) as { token?: unknown }).token;

    return typeof Saved === "string" && Saved.length >= 32 ? Saved : null;
  } catch {
    return null;
  }
}

export function EnsureToken() {
  if (Current) {
    return Current;
  }

  Current = Stored();

  if (!Current) {
    Current = crypto.randomBytes(32).toString("hex");
    Remember(Current);
  }

  return Current;
}

export function HandToken() {
  return WritePluginSetting("BridgeToken", EnsureToken());
}

const PlaytestKeys = new Map<string, number>();

export function IssuePlaytestKey(): string {
  const Key = crypto.randomBytes(24).toString("hex");

  PlaytestKeys.set(Key, Date.now() + 6 * 60 * 60 * 1000);

  return Key;
}

export function RevokePlaytestKey(Key: unknown) {
  if (typeof Key === "string") {
    PlaytestKeys.delete(Key);
  }
}

export function PlaytestKeyMatches(Given: unknown): boolean {
  if (typeof Given !== "string") {
    return false;
  }

  const Expires = PlaytestKeys.get(Given);

  if (Expires === undefined) {
    return false;
  }

  if (Expires < Date.now()) {
    PlaytestKeys.delete(Given);

    return false;
  }

  return true;
}

export function PlaytestLive(): boolean {
  for (const [Key, Expires] of PlaytestKeys) {
    if (Expires >= Date.now()) {
      return true;
    }

    PlaytestKeys.delete(Key);
  }

  return false;
}

export function TokenMatches(Given: unknown): boolean {
  const Wanted = EnsureToken();

  if (typeof Given !== "string") {
    return false;
  }

  const Offered = Buffer.from(Given, "utf8");
  const Expected = Buffer.from(Wanted, "utf8");

  if (Offered.length !== Expected.length) {
    return false;
  }

  return crypto.timingSafeEqual(Offered, Expected);
}