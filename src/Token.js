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

  WritePluginSetting("BridgeToken", Current);

  return Current;
}

export function TokenMatches(Given) {
  const Wanted = EnsureToken();

  if (typeof Given !== "string" || Given.length !== Wanted.length) {
    return false;
  }

  return crypto.timingSafeEqual(Buffer.from(Given), Buffer.from(Wanted));
}
