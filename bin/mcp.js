#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import fs from "node:fs";
import { DefaultPort, TokenFile } from "../src/Config.js";
import { StudioTools } from "../src/Tools.js";
import { Describe as DescribePresence } from "../src/StudioPresence.js";

const Port = Number(process.env.CLAUDIO_PORT) || DefaultPort;

function Key() {
  try {
    return JSON.parse(fs.readFileSync(TokenFile, "utf8").replace(/^﻿/, "")).token || "";
  } catch {
    return "";
  }
}

async function Get(Where) {
  try {
    const Answer = await fetch(`http://127.0.0.1:${Port}${Where}`, { headers: { "x-claudio-token": Key() } });

    return Answer.ok ? await Answer.json() : null;
  } catch {
    return null;
  }
}

async function Send(Role, Kind, Input, Timeout) {
  try {
    const Answer = await fetch(`http://127.0.0.1:${Port}/studio/enqueue`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-claudio-token": Key() },
      body: JSON.stringify({ kind: Kind, input: Input, role: Role, timeout: Timeout }),
    });

    if (!Answer.ok) {
      return { error: `The Claudio bridge answered ${Answer.status}. Is it running?` };
    }

    return await Answer.json();
  } catch (Trouble) {
    return { error: `Could not reach the Claudio bridge on port ${Port}: ${Trouble.message}. Start it with "claudio" and open a place in Studio.` };
  }
}

const Server = new McpServer({ name: "claudio", version: "1.0.0" });

for (const Entry of StudioTools({
  Reach: (Kind, Input, Timeout) => Send(undefined, Kind, Input, Timeout),
  ReachIn: (Role, Kind, Input, Timeout) => Send(Role, Kind, Input, Timeout),
  Presence: async () => {
    const Found = await Get("/studio/presence");

    return Found ? DescribePresence(Found) : "The Claudio bridge is not running, so nothing can be reached. Start it with \"claudio\".";
  },
  RuntimeLive: async () => {
    const Found = await Get("/studio/presence");

    return Boolean(Found && Found.runtimeSeen && Date.now() - Found.runtimeSeen < 6000);
  },
})) {
  Server.tool(Entry.Name, Entry.Description, Entry.Schema, Entry.Run);
}

await Server.connect(new StdioServerTransport());