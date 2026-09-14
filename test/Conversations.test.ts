import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

const Home = fs.mkdtempSync(path.join(os.tmpdir(), "claudio-test-"));

process.env.USERPROFILE = Home;
process.env.HOME = Home;
process.env.APPDATA = path.join(Home, "Roaming");

const { GetConversation, StripContext, ExtractContext } = await import("../src/Conversations.js");

const Picture = { type: "image", source: { type: "base64", media_type: "image/png", data: "aGk=" } };

function Line(Type: string, Content: unknown, Extra?: Record<string, unknown>) {
  return JSON.stringify({ type: Type, timestamp: "2026-09-13T10:00:00.000Z", message: { role: Type === "assistant" ? "assistant" : "user", content: Content }, ...Extra });
}

function WriteTranscript(Id: string, Lines: string[]) {
  const Folder = path.join(Home, ".claude", "projects", "C--Users-Test-Place");

  fs.mkdirSync(Folder, { recursive: true });
  fs.writeFileSync(path.join(Folder, `${Id}.jsonl`), Lines.join("\n") + "\n");
}

test("a reply keeps its calls with their arguments and results", () => {
  WriteTranscript("calls", [
    Line("user", [{ type: "text", text: "count the parts" }]),
    Line("assistant", [{ type: "tool_use", id: "t1", name: "mcp__claudio__execute", input: { code: "return 4", readOnly: true } }]),
    Line("user", [{ type: "tool_result", tool_use_id: "t1", content: [{ type: "text", text: "4" }] }]),
    Line("assistant", [{ type: "text", text: "There are 4." }]),
  ]);

  const Found = GetConversation("calls")!;

  assert.equal(Found.messages.length, 2);
  assert.equal(Found.messages[1].role, "assistant");
  assert.equal(Found.messages[1].calls!.length, 1);
  assert.equal(Found.messages[1].calls![0].name, "mcp__claudio__execute");
  assert.equal(Found.messages[1].calls![0].input, "code: return 4\nreadOnly: true");
  assert.equal(Found.messages[1].calls![0].output, "4");
  assert.equal(Found.messages[1].calls![0].status, "done");
  assert.equal(Found.messages[1].calls![0].image, null);
});

test("a failed call is marked and its output kept", () => {
  WriteTranscript("failed", [
    Line("user", [{ type: "text", text: "go" }]),
    Line("assistant", [{ type: "tool_use", id: "t1", name: "Bash", input: { command: "ls /nope", description: "Look" } }]),
    Line("user", [{ type: "tool_result", tool_use_id: "t1", is_error: true, content: [{ type: "text", text: "No such file" }] }]),
    Line("assistant", [{ type: "text", text: "It is not there." }]),
  ]);

  const Call = GetConversation("failed")!.messages[1].calls![0];

  assert.equal(Call.status, "error");
  assert.equal(Call.output, "No such file");
});

test("a picture a call produced is tied to that call and counted for the message", () => {
  WriteTranscript("pictures", [
    Line("user", [{ type: "text", text: "look" }]),
    Line("assistant", [{ type: "tool_use", id: "t1", name: "mcp__claudio__capture", input: { of: "viewport" } }]),
    Line("user", [{ type: "tool_result", tool_use_id: "t1", content: [{ type: "text", text: "800x600" }, Picture] }]),
    Line("assistant", [{ type: "tool_use", id: "t2", name: "Read", input: { file_path: "C:/a.png" } }]),
    Line("user", [{ type: "tool_result", tool_use_id: "t2", content: [Picture] }]),
    Line("assistant", [{ type: "text", text: "Two pictures." }]),
  ]);

  const Reply = GetConversation("pictures")!.messages[1];

  assert.deepEqual(Reply.images, [1, 2]);
  assert.equal(Reply.calls![0].image, 1);
  assert.equal(Reply.calls![1].image, 2);
  assert.equal(Reply.calls![0].output, "800x600");
});

test("a message sent mid turn splits the reply where it landed", () => {
  WriteTranscript("midturn", [
    Line("user", [{ type: "text", text: "start" }]),
    Line("assistant", [{ type: "text", text: "First half." }]),
    Line("user", [{ type: "text", text: "also this" }]),
    Line("assistant", [{ type: "text", text: "Second half." }]),
  ]);

  const Roles = GetConversation("midturn")!.messages.map((Message) => `${Message.role}:${Message.text}`);

  assert.deepEqual(Roles, ["user:start", "assistant:First half.", "user:also this", "assistant:Second half."]);
});

test("two replies with nothing between them join as one, and their pictures follow", () => {
  WriteTranscript("joined", [
    Line("user", [{ type: "text", text: "go" }]),
    Line("assistant", [{ type: "text", text: "One." }]),
    Line("assistant", [{ type: "tool_use", id: "t1", name: "mcp__claudio__capture", input: {} }]),
    Line("user", [{ type: "tool_result", tool_use_id: "t1", content: [Picture] }]),
    Line("assistant", [{ type: "text", text: "Two." }]),
  ]);

  const Messages = GetConversation("joined")!.messages;

  assert.equal(Messages.length, 2);
  assert.equal(Messages[1].text, "One.\n\nTwo.");
  assert.deepEqual(Messages[1].images, [1]);
  assert.equal(Messages[1].calls![0].image, 1);
});

test("attached context is stripped from what the user is shown to have said", () => {
  WriteTranscript("context", [
    Line("user", [{ type: "text", text: "fix it\n\n<studio_context>\nlots\n</studio_context>" }]),
    Line("assistant", [{ type: "text", text: "Done." }]),
  ]);

  assert.equal(GetConversation("context")!.messages[0].text, "fix it");
});

test("sidechain and meta lines are not messages", () => {
  WriteTranscript("side", [
    Line("user", [{ type: "text", text: "real" }]),
    Line("user", [{ type: "text", text: "<system-reminder>ignored</system-reminder>" }], { isMeta: true }),
    Line("assistant", [{ type: "text", text: "sub agent" }], { isSidechain: true }),
    Line("assistant", [{ type: "text", text: "Reply." }]),
  ]);

  const Messages = GetConversation("side")!.messages;

  assert.equal(Messages.length, 2);
  assert.equal(Messages[1].text, "Reply.");
});

test("tool output is capped at two thousand characters", () => {
  WriteTranscript("long", [
    Line("user", [{ type: "text", text: "go" }]),
    Line("assistant", [{ type: "tool_use", id: "t1", name: "Bash", input: { command: "cat big" } }]),
    Line("user", [{ type: "tool_result", tool_use_id: "t1", content: [{ type: "text", text: "x".repeat(5000) }] }]),
    Line("assistant", [{ type: "text", text: "Long." }]),
  ]);

  assert.equal(GetConversation("long")!.messages[1].calls![0].output.length, 2000);
});

test("an unknown conversation is null", () => {
  assert.equal(GetConversation("missing"), null);
});

test("StripContext and ExtractContext split a prompt into its halves", () => {
  const Text = "hello\n\n<studio_place>\nMyPlace\n</studio_place>\n\nI changed these in Studio myself since my last message:\n- Moved Part";

  assert.equal(StripContext(Text), "hello");
  assert.ok(ExtractContext(Text).includes("<studio_place>"));
  assert.ok(ExtractContext(Text).includes("Moved Part"));
  assert.equal(StripContext("plain"), "plain");
  assert.equal(ExtractContext("plain"), "");
});