import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

const Home = fs.mkdtempSync(path.join(os.tmpdir(), "claudio-test-"));

process.env.USERPROFILE = Home;
process.env.HOME = Home;
process.env.APPDATA = path.join(Home, "Roaming");

const { EnsureToken, IssuePlaytestKey, PlaytestKeyMatches, PlaytestLive, RevokePlaytestKey, TokenMatches } = await import("../src/Token.js");
const { Deliver, Request, Take } = await import("../src/Studio.js");

test("a playtest key is not the bridge token and does not pass for it", () => {
  const Key = IssuePlaytestKey();

  assert.notEqual(Key, EnsureToken());
  assert.equal(TokenMatches(Key), false);
  assert.equal(PlaytestKeyMatches(Key), true);
  RevokePlaytestKey(Key);
});

test("a revoked playtest key stops working and the playtest is no longer live", () => {
  const Key = IssuePlaytestKey();

  assert.equal(PlaytestLive(), true);
  RevokePlaytestKey(Key);
  assert.equal(PlaytestKeyMatches(Key), false);
  assert.equal(PlaytestLive(), false);
});

test("an unknown or malformed key is refused", () => {
  assert.equal(PlaytestKeyMatches("nope"), false);
  assert.equal(PlaytestKeyMatches(undefined), false);
  assert.equal(PlaytestKeyMatches(42), false);
});

test("a playtest cannot answer a job meant for the editor", async () => {
  const Asked = Request("find", {text: "x"}, 2000, "edit");
  const Job = Take("edit");

  assert.ok(Job);
  assert.equal(Deliver(Job!.id, {text: "forged"}, true), false);
  assert.equal(Deliver(Job!.id, {text: "real"}, false), true);
  assert.deepEqual(await Asked, {text: "real"});
});

test("a playtest can answer a job meant for the running session", async () => {
  const Asked = Request("execute", {code: "return 1"}, 2000, "server");
  const Job = Take("server");

  assert.equal(Deliver(Job!.id, {result: "1"}, true), true);
  assert.deepEqual(await Asked, {result: "1"});
});

test("a job nobody takes says so, and one taken but slow says it may still be running", async () => {
  const Missed = await Request("find", {}, 50, "nobody");

  assert.match(String((Missed as {error: string}).error), /did not pick this up/);

  const Slow = Request("execute", {}, 50, "server");

  Take("server");
  assert.match(String(((await Slow) as {error: string}).error), /may still be running/);
});