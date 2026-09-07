import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { TokenFile } from "./Config.js";
import { WritePluginSetting } from "./PluginSettings.js";

let Current = null;

function Remember(Value) {
  try {
    fs.mkdirSync(path.dirname(TokenFile), { recursive: true });
    fs.writeFileSync(TokenFile, JSON.stringify({ token: Value }, null, 2), { mode: 0o600 });

    return true;
  } catch (Error) {
    console.error(`Could not save the bridge key to ${TokenFile}: ${Error.message}`);
    console.error("A new key will be made every time the bridge starts, and Studio will have to be told each time.");

    return false;
  }
}

function Stored() {
  try {
    const Saved = JSON.parse(fs.readFileSync(TokenFile, "utf8").replace(/^﻿/, "")).token;

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

export function TokenMatches(Given) {
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
