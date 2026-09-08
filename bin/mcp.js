#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import fs from "node:fs";
import { DefaultPort, TokenFile } from "../src/Config.js";
import { ExecuteReport, LintReport } from "../src/Ask.js";

const Port = Number(process.env.CLAUDIO_PORT) || DefaultPort;

function Key() {
  try {
    return JSON.parse(fs.readFileSync(TokenFile, "utf8").replace(/^﻿/, "")).token || "";
  } catch {
    return "";
  }
}

async function Ask(Kind, Input) {
  try {
    const Answer = await fetch(`http://127.0.0.1:${Port}/studio/enqueue`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-claudio-token": Key() },
      body: JSON.stringify({ kind: Kind, input: Input }),
    });

    if (!Answer.ok) {
      return { error: `The Claudio bridge answered ${Answer.status}. Is it running?` };
    }

    return await Answer.json();
  } catch (Trouble) {
    return { error: `Could not reach the Claudio bridge on port ${Port}: ${Trouble.message}. Start it with "claudio" and open a place in Studio.` };
  }
}

function Say(Found) {
  if (!Found) {
    return "Studio did not answer.";
  }

  if (Found.error) {
    return Found.error;
  }

  if (Found.text) {
    return Found.text;
  }

  return JSON.stringify(Found);
}

const Server = new McpServer({ name: "claudio", version: "1.0.0" });

Server.tool(
  "lint",
  "Check scripts in the open place for analyzer warnings, including scripts nobody has edited. Pass paths to narrow it, or leave it empty to check everything. Report what it finds rather than fixing unasked, because pre-existing warnings were already there.",
  { paths: z.array(z.string()).optional() },
  async (Input) => ({ content: [{ type: "text", text: LintReport(await Ask("lint", { paths: Input.paths || [] })) }] }),
);

Server.tool(
  "execute",
  "Run Luau inside the open place and get back what it returned, what it printed, and where it failed. Changes are recorded as one undo step; pass readOnly when you only want to look. Call _G.ClaudioFresh(module) to require past the cache.",
  { code: z.string(), readOnly: z.boolean().optional(), label: z.string().optional() },
  async (Input) => ({ content: [{ type: "text", text: ExecuteReport(await Ask("execute", { code: Input.code, readOnly: Input.readOnly === true, label: Input.label })) }] }),
);

Server.tool(
  "playtest",
  "Start, stop or inspect a playtest of the open place. Always stop what you started. Check status first rather than assuming. This runs without a player character, so LocalPlayer and PlayerGui are not available.",
  { action: z.enum(["start", "stop", "status"]) },
  async (Input) => ({ content: [{ type: "text", text: Say(await Ask("playtest", { action: Input.action })) }] }),
);

Server.tool(
  "press",
  "Press a button in the running experience by naming its instance path, rather than by guessing screen coordinates. Needs a play session with a character. A press that reaches nothing still reports as sent, so check the place afterwards.",
  { path: z.string() },
  async (Input) => ({ content: [{ type: "text", text: Say(await Ask("press", { path: Input.path })) }] }),
);

await Server.connect(new StdioServerTransport());
