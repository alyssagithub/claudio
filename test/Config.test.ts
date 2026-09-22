import assert from "node:assert/strict";
import { test } from "node:test";
import { AutoBias, AutoLevels, AutoTier, AutoTiers } from "../src/Config.js";

test("the effort slider maps evenly onto a bias from zero to one", () => {
  assert.equal(AutoBias("low"), 0);
  assert.equal(AutoBias("max"), 1);
  assert.equal(AutoBias("high"), 0.5);
});

test("no saved effort means extra", () => {
  assert.equal(AutoBias(""), AutoBias("xhigh"));
  assert.equal(AutoBias(undefined), AutoBias("xhigh"));
});

test("the lowest slider and an easy message pick the cheapest tier", () => {
  assert.deepEqual(AutoTier(0, AutoBias("low")), AutoTiers[0]);
});

test("the highest slider and a hard message pick the top tier", () => {
  assert.deepEqual(AutoTier(1, AutoBias("max")), AutoTiers[AutoTiers.length - 1]);
});

test("a hard message never picks a lower tier than an easy one at the same slider", () => {
  for (const Level of AutoLevels) {
    const Easy = AutoTiers.indexOf(AutoTier(0, AutoBias(Level)));
    const Hard = AutoTiers.indexOf(AutoTier(1, AutoBias(Level)));

    assert.ok(Hard >= Easy, `${Level}: hard ${Hard} below easy ${Easy}`);
  }
});

test("a score past one counts as one", () => {
  assert.deepEqual(AutoTier(5, AutoBias("medium")), AutoTier(1, AutoBias("medium")));
});

test("every tier names a model and a delegate", () => {
  for (const Tier of AutoTiers) {
    assert.equal(typeof Tier.model, "string");
    assert.equal(typeof Tier.delegate, "string");
  }
});
test("the step down ladder goes to the next model down and never repeats one", async () => {
  const { LadderBelow } = await import("../src/ClaudeSession.js");
  const Below = LadderBelow("claude-fable-5-1[1m]");

  assert.equal(Below[0], "claude-fable-5");
  assert.equal(new Set(Below).size, Below.length);
  assert.equal(LadderBelow("haiku").length, 0);
  assert.equal(LadderBelow("opus[1m]")[0], "claude-opus-5");
});