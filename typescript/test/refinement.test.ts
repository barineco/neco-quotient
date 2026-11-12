import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  residual,
  resolved,
  sameOutcome,
  stopped,
  type OutcomeComparison,
  type RefinementOutcome,
} from "../src/index.ts";

type Outcome = RefinementOutcome<string, string, string>;

const comparison: OutcomeComparison<string, string, string> = {
  sameValue: (left, right) => left === right,
  sameResidual: (left, right) => left === right,
  sameCause: (left, right) => left === right,
};

function same(left: Outcome, right: Outcome): boolean {
  return sameOutcome(left, right, comparison);
}

describe("RefinementOutcome", () => {
  it("builds the three cases with their parts", () => {
    const determined: Outcome = resolved("value");
    const remaining: Outcome = residual("value", ["residual-a", "residual-b"]);
    const halted: Outcome = stopped("value", ["residual-a"], "budget");
    assert.deepEqual(determined, { kind: "resolved", value: "value" });
    assert.equal(remaining.kind, "residual");
    assert.equal(halted.kind, "stopped");
    if (remaining.kind === "residual") {
      assert.deepEqual(remaining.residuals.values, ["residual-a", "residual-b"]);
    }
    if (halted.kind === "stopped") {
      assert.deepEqual(halted.residuals.values, ["residual-a"]);
      assert.equal(halted.cause, "budget");
    }
  });

  it("freezes the outcome and copies the residual list", () => {
    const residuals = ["residual-a"];
    const outcome: Outcome = residual("value", residuals);
    residuals.push("residual-b");
    assert.ok(Object.isFrozen(outcome));
    if (outcome.kind === "residual") {
      assert.deepEqual(outcome.residuals.values, ["residual-a"]);
    }
  });

  it("treats equal cases with equal parts as equal", () => {
    assert.ok(same(resolved("value"), resolved("value")));
    assert.ok(same(residual("value", ["residual-a"]), residual("value", ["residual-a"])));
    assert.ok(same(stopped("value", ["residual-a"], "budget"), stopped("value", ["residual-a"], "budget")));
  });

  it("ignores residual order and duplicates", () => {
    assert.ok(same(
      residual("value", ["residual-b", "residual-a", "residual-a"]),
      residual("value", ["residual-a", "residual-b"]),
    ));
    assert.ok(same(
      stopped("value", ["residual-b", "residual-a"], "budget"),
      stopped("value", ["residual-a", "residual-b"], "budget"),
    ));
  });

  it("distinguishes residual members", () => {
    assert.ok(!same(
      residual("value", ["residual-a", "residual-b"]),
      residual("value", ["residual-a", "residual-c"]),
    ));
    assert.ok(!same(residual("value", ["residual-a"]), residual("value", ["residual-a", "residual-b"])));
  });

  it("distinguishes value and cause", () => {
    assert.ok(!same(resolved("value"), resolved("other")));
    assert.ok(!same(residual("value", ["residual-a"]), residual("other", ["residual-a"])));
    assert.ok(!same(
      stopped("value", ["residual-a"], "budget"),
      stopped("value", ["residual-a"], "timeout"),
    ));
  });

  it("distinguishes different cases", () => {
    const residuals = ["residual-a"];
    assert.ok(!same(resolved("value"), residual("value", residuals)));
    assert.ok(!same(residual("value", residuals), stopped("value", residuals, "budget")));
    assert.ok(!same(resolved("value"), stopped("value", [], "budget")));
    assert.ok(!same(stopped("value", [], "budget"), resolved("value")));
    assert.ok(!same(residual("value", []), resolved("value")));
  });
});
