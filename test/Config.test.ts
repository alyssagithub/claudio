import assert from "node:assert/strict";
import { test } from "node:test";

test("the step down ladder goes to the next model down and never repeats one", async () => {
  const { LadderBelow } = await import("../src/ClaudeSession.js");
  const Below = LadderBelow("claude-fable-5-1[1m]");

  assert.equal(Below[0], "claude-fable-5");
  assert.equal(new Set(Below).size, Below.length);
  assert.equal(LadderBelow("haiku").length, 0);
  assert.equal(LadderBelow("opus[1m]")[0], "claude-opus-5");
});