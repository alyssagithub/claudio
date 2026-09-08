#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import fs from "node:fs";
import { DefaultPort, TokenFile } from "../src/Config.js";
import { ExecuteReport, LintReport, ReadReport, PropertyReport, ApiReport } from "../src/Ask.js";
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

async function AskAs(Role, Kind, Input) {
  try {
    const Answer = await fetch(`http://127.0.0.1:${Port}/studio/enqueue`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-claudio-token": Key() },
      body: JSON.stringify({ kind: Kind, input: Input, role: Role }),
    });

    return Answer.ok ? await Answer.json() : { error: `The Claudio bridge answered ${Answer.status}.` };
  } catch (Trouble) {
    return { error: `Could not reach the Claudio bridge: ${Trouble.message}` };
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
  "instances",
  "Say whether Studio is open and whether the Claudio plugin has checked in. Ask this before assuming nothing is connected, and never open Studio yourself on the strength of an empty answer.",
  {},
  async () => {
    const Found = await Get("/studio/presence");

    return { content: [{ type: "text", text: Found ? DescribePresence(Found) : "The Claudio bridge is not answering, so nothing can be said about Studio." }] };
  },
);

Server.tool(
  "read",
  "Read a part of the open place in one call: the instance tree under a path, plus the source of scripts in it. Prefer this over walking the tree with separate calls.",
  { path: z.string().optional(), depth: z.number().optional(), contains: z.string().optional() },
  async (Input) => ({ content: [{ type: "text", text: ReadReport(await Ask("read", { path: Input.path || "game", depth: Input.depth, contains: Input.contains })) }] }),
);

Server.tool(
  "properties",
  "Read an instance's properties, listing every property its class actually has and naming any that could not be read, so a missing one is never mistaken for an unset one.",
  { path: z.string(), names: z.array(z.string()).optional() },
  async (Input) => ({ content: [{ type: "text", text: PropertyReport(await Ask("properties", { path: Input.path, names: Input.names })) }] }),
);

Server.tool(
  "api",
  "Ask the running engine about the Roblox API: a class's properties, methods and events with full signatures, parameter names, return types, what it inherits and what inherits from it, which members are deprecated or read only, and what security each needs. This is the version of Roblox actually installed, so prefer it over remembering an API or reading documentation that may describe a different version. Narrow with member for one member, search to find a class, enum or member by name, or enumName for an enum's items.",
  { className: z.string().optional(), member: z.string().optional(), search: z.string().optional(), enumName: z.string().optional() },
  async (Input) => ({ content: [{ type: "text", text: ApiReport(await Ask("api", { className: Input.className, member: Input.member, search: Input.search, enumName: Input.enumName })) }] }),
);

Server.tool(
  "modify",
  "Change the place with one undo step: set properties, create, delete, rename or reparent. Prefer this over writing a script for a change this can express, because the arguments are checked and the change is reversible.",
  {
    action: z.enum(["set", "create", "delete", "rename", "reparent"]),
    path: z.string().optional(),
    parent: z.string().optional(),
    className: z.string().optional(),
    name: z.string().optional(),
    properties: z.record(z.any()).optional(),
    label: z.string().optional(),
  },
  async (Input) => ({ content: [{ type: "text", text: Say(await Ask("modify", Input)) }] }),
);

Server.tool(
  "capture",
  "Take a picture of the Studio viewport. Give around with an instance path to crop tightly to that thing, which works for a part, a model or any on screen GuiObject, and costs a fraction of a whole viewport to look at. Give path to point the camera at something first, or x, y, width and height to crop by hand. The camera is always put back where it was. Plugin windows are not in the viewport, so they cannot be captured this way.",
  { around: z.string().optional(), padding: z.number().optional(), path: z.string().optional(), x: z.number().optional(), y: z.number().optional(), width: z.number().optional(), height: z.number().optional() },
  async (Input) => {
    const { EncodePixels } = await import("../src/Capture.js");

    let Framed = null;

    if (Input.path) {
      Framed = await Ask("frame", { path: Input.path });

      if (Framed && Framed.error) {
        return { content: [{ type: "text", text: Framed.error }] };
      }
    }

    const Shot = await Ask("shoot", { x: Input.x, y: Input.y, width: Input.width, height: Input.height, around: Input.around, padding: Input.padding });

    if (Framed && Framed.restore) {
      await Ask("frame", { restore: true });
    }

    if (!Shot || Shot.error) {
      return { content: [{ type: "text", text: (Shot && Shot.error) || "Studio did not answer." }] };
    }

    const Made = EncodePixels(Shot.width, Shot.height, Shot.pixels);

    if (Made.error) {
      return { content: [{ type: "text", text: Made.error }] };
    }

    return {
      content: [
        { type: "image", data: Made.data, mimeType: "image/png" },
        { type: "text", text: `${Shot.width}x${Shot.height} of the ${Shot.viewport} viewport${Shot.around ? `, cropped to ${Shot.around}` : ""}${Framed && Framed.framed ? `, framed on ${Framed.framed}` : ""}` },
      ],
    };
  },
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
  { action: z.enum(["start", "stop", "status", "players"]), mode: z.enum(["play", "run", "multiplayer"]).optional(), players: z.number().optional() },
  async (Input) => {
    const Found = await Ask("playtest", { action: Input.action, mode: Input.mode, players: Input.players });

    if (Found && Found.relay) {
      const Inside = await AskAs("server", "playtest", { action: Found.relay, players: Found.players });

      return { content: [{ type: "text", text: Say(Inside) }] };
    }

    return { content: [{ type: "text", text: Say(Found) }] };
  },
);

Server.tool(
  "press",
  "Press a button in the running experience by naming its instance path, rather than by guessing screen coordinates. Needs a play session with a character. A press that reaches nothing still reports as sent, so check the place afterwards.",
  { path: z.string() },
  async (Input) => ({ content: [{ type: "text", text: Say(await Ask("press", { path: Input.path })) }] }),
);

await Server.connect(new StdioServerTransport());
