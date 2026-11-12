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
import { canonicalJson, readBytes, readJson } from "./support.ts";

const CASES_URL = new URL("../../comparison/refinement-outcome/cases.json", import.meta.url);
const OUTCOMES_URL = new URL("../../comparison/refinement-outcome/lean-outcomes.json", import.meta.url);

type WireOutcome =
  | { readonly kind: "resolved"; readonly value: string }
  | { readonly kind: "residual"; readonly value: string; readonly residuals: readonly string[] }
  | {
      readonly kind: "stopped";
      readonly value: string;
      readonly residuals: readonly string[];
      readonly cause: string;
    };

type CaseRow = { readonly name: string; readonly left: WireOutcome; readonly right: WireOutcome };
type LeanRow = CaseRow & { readonly same: boolean };

type Outcome = RefinementOutcome<string, string, string>;

const comparison: OutcomeComparison<string, string, string> = {
  sameValue: (left, right) => left === right,
  sameResidual: (left, right) => left === right,
  sameCause: (left, right) => left === right,
};

function outcomeOf(wire: WireOutcome): Outcome {
  switch (wire.kind) {
    case "resolved":
      return resolved(wire.value);
    case "residual":
      return residual(wire.value, wire.residuals);
    case "stopped":
      return stopped(wire.value, wire.residuals, wire.cause);
  }
}

function sortedResiduals(values: readonly string[]): readonly string[] {
  return [...values].sort((left, right) => (left < right ? -1 : left > right ? 1 : 0));
}

function outcomeJson(outcome: Outcome): WireOutcome {
  switch (outcome.kind) {
    case "resolved":
      return { kind: "resolved", value: outcome.value };
    case "residual":
      return { kind: "residual", value: outcome.value, residuals: sortedResiduals(outcome.residuals.values) };
    case "stopped":
      return {
        kind: "stopped",
        value: outcome.value,
        residuals: sortedResiduals(outcome.residuals.values),
        cause: outcome.cause,
      };
  }
}

function outcomesOf(cases: readonly CaseRow[]): LeanRow[] {
  return cases.map((row) => {
    const left = outcomeOf(row.left);
    const right = outcomeOf(row.right);
    return {
      name: row.name,
      left: outcomeJson(left),
      right: outcomeJson(right),
      same: sameOutcome(left, right, comparison),
    };
  });
}

const cases = readJson<CaseRow[]>(CASES_URL);
const lean = readJson<LeanRow[]>(OUTCOMES_URL);

describe("refinement outcome comparison", () => {
  it("reads the input files in canonical form", () => {
    assert.equal(canonicalJson(cases as never), readBytes(CASES_URL).toString("utf8"));
    assert.equal(canonicalJson(lean as never), readBytes(OUTCOMES_URL).toString("utf8"));
  });

  it("matches the Lean outcomes", () => {
    assert.deepEqual(outcomesOf(cases), lean);
  });

  it("has unique names and both verdicts", () => {
    const names = cases.map((row) => row.name);
    assert.equal(new Set(names).size, names.length);
    assert.deepEqual(names, lean.map((row) => row.name));
    assert.deepEqual(new Set(lean.map((row) => row.same)), new Set([true, false]));
  });

  it("keeps reordered inputs the same and swapped cases different", () => {
    const sameByName = new Map(lean.map((row) => [row.name, row.same]));
    assert.equal(sameByName.get("residual_order_and_duplicates"), true);
    assert.equal(sameByName.get("stopped_order_and_duplicates"), true);
    for (const name of ["case_resolved_residual", "case_residual_stopped", "case_resolved_stopped"]) {
      assert.equal(sameByName.get(name), false);
    }
  });

  it("detects an order-sensitive comparison as a mutation", () => {
    const ordered = cases.map((row) => ({
      name: row.name,
      same: canonicalJson(row.left as never) === canonicalJson(row.right as never),
    }));
    assert.notDeepEqual(ordered, lean.map((row) => ({ name: row.name, same: row.same })));
  });
});
