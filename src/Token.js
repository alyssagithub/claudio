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
  } catch (Error) {
    console.error("Could not save the bridge token: " + Error.message);
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

// The same secret every run, so a bridge restart does not lock out a Studio
// that is already open. It is handed to the plugin through Studio's plugin
// settings, which a playtested place cannot read.
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

// Studio rewrites its settings from memory when it closes, so the handover is
// repeated at every bridge start rather than assumed to have stuck.
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
