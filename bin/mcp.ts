#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import fs from "node:fs";
import http from "node:http";
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

async function Get<Found>(Where: string): Promise<Found | null> {
  try {
    const Answer = await fetch(`http://127.0.0.1:${Port}${Where}`, {headers: {"x-claudio-token": Key()}});

    return Answer.ok ? await Answer.json() as Found : null;
  } catch {
    return null;
  }
}

async function Send<Found>(Role: string | undefined, Kind: string, Input: unknown, Timeout: number | undefined): Promise<Found> {
  try {
    const Answer = await new Promise<{Status: number, Text: string}>((Resolve, Reject) => {
      const Sending = http.request({
        host: "127.0.0.1",
        port: Port,
        path: "/studio/enqueue",
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-claudio-token": Key(),
        },
      }, (Reply) => {
        let Text = "";

        Reply.setEncoding("utf8");
        Reply.on("data", (Chunk: string) => {
          Text += Chunk;
        });
        Reply.on("end", () => Resolve({Status: Reply.statusCode || 0, Text}));
        Reply.on("error", Reject);
      });

      Sending.on("error", Reject);
      Sending.end(JSON.stringify({
        kind: Kind,
        input: Input,
        role: Role,
        timeout: Timeout,
      }));
    });

    if (Answer.Status < 200 || Answer.Status >= 300) {
      return {error: `The Claudio bridge answered ${Answer.Status}. Is it running?`} as Found;
    }

    return JSON.parse(Answer.Text) as Found;
  } catch (Trouble) {
    return {error: `Could not reach the Claudio bridge on port ${Port}: ${(Trouble as Error).message}. Start it with "claudio" and open a place in Studio.`} as Found;
  }
}

const Server = new McpServer({
  name: "claudio",
  version: "1.0.0",
});

for (const Entry of StudioTools({
  Reach: <Found,>(Kind: string, Input?: unknown, Timeout?: number): Promise<Found> => Send<Found>(undefined, Kind, Input, Timeout),
  ReachIn: <Found,>(Role: string, Kind: string, Input?: unknown, Timeout?: number): Promise<Found> => Send<Found>(Role, Kind, Input, Timeout),
  Presence: async () => {
    const Found = await Get<Parameters<typeof DescribePresence>[0]>("/studio/presence");

    return Found ? DescribePresence(Found) : "The Claudio bridge is not running, so nothing can be reached. Start it with \"claudio\".";
  },
  RuntimeLive: async () => {
    const Found = await Get<{ runtimeSeen?: number }>("/studio/presence");

    return Boolean(Found && Found.runtimeSeen && Date.now() - Found.runtimeSeen < 6000);
  },
})) {
  Server.tool(Entry.Name, Entry.Description, Entry.Schema, Entry.Run);
}

await Server.connect(new StdioServerTransport());