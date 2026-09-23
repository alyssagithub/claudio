import assert from "node:assert/strict";
import { test } from "node:test";

const { ChooseModel, RecordTurnOutcome } = await import("../src/Models.js");

test("warming a chat up does not change the model its next message gets", () => {
  for (const Id of ["warmed", "cold"]) {
    RecordTurnOutcome(Id, {Failed: true});
    RecordTurnOutcome(Id, {Failed: true});
    RecordTurnOutcome(Id, {Failed: true});
  }

  ChooseModel("warmed", "", false, 0.5, false);

  assert.deepEqual(ChooseModel("warmed", "rename the part", false, 0.5, true), ChooseModel("cold", "rename the part", false, 0.5, true));
});