import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  RuleTable,
  admit,
  projectionDigests,
  type Certificate,
  type Comparison,
  type Expected,
  type Result,
  type Mismatch,
  type Rule,
  residualSet,
} from "../src/index.ts";
import { stringComparison } from "./support.ts";

class Coordinate {
  readonly label: string;
  readonly self: unknown;

  constructor(label: string) {
    this.label = label;
    this.self = this;
  }

  toString(): string {
    return this.label;
  }
}

type Cert = Certificate<string, string, Coordinate, string, string, string>;
type Exp = Expected<string, string, Coordinate, string, string>;

const emptyRule: Rule<string, string, Coordinate, string, string> = () => new Map();

function table() {
  const built = RuleTable.create([["rule@1", emptyRule]] as const);
  if (!built.ok) throw new Error("fixture table has unique revisions");
  return built.value;
}

function rejected<T>(result: Result<T, Mismatch<string>>): Mismatch<string> {
  assert.equal(result.ok, false);
  if (result.ok) throw new Error("unreachable");
  return result.error;
}

describe("a coordinate with a self reference is reported as a mismatch", () => {
  it("uses the standard string form of the coordinate values at the coordinate condition", () => {
    const comparison: Comparison<string, string, Coordinate, string, string> = {
      ...stringComparison,
      sameCoordinate: (left, right) => Object.is(left, right),
    };
    const certificate: Cert = {
      ruleRevision: "rule@1",
      source: { identity: "src", revision: "1" },
      coordinate: new Coordinate("actual-label"),
      digests: projectionDigests(new Map()),
      residuals: residualSet([]),
      observations: "d",
      evidence: "e",
    };
    const expected: Exp = {
      ruleRevision: "rule@1",
      source: { identity: "src", revision: "1" },
      coordinate: new Coordinate("expected-label"),
      observations: "d",
      residuals: residualSet([]),
    };
    const mismatch = rejected(admit(table(), certificate, expected, "caller", comparison));
    assert.equal(mismatch.checks.source.kind, "established");
    if (mismatch.checks.source.kind !== "established") return;
    const result = mismatch.checks.source.children.coordinate;
    assert.equal(result.kind, "mismatched");
    if (result.kind !== "mismatched") return;
    assert.equal(result.failure.condition, "coordinate");
    assert.equal(result.failure.expected, "expected-label");
    assert.equal(result.failure.actual, "actual-label");
    assert.equal(result.failure.provenance, "caller");
  });
});

describe("residual lists are reported with their actual fields", () => {
  it("renders a symbol residual through its standard string form", () => {
    const symbolic = Symbol("residual-a");
    const comparison: Comparison<string, string, string, string, symbol> = {
      ...stringComparison,
      sameResidual: (left, right) => left === right,
    };
    const certificate: Certificate<string, string, string, string, symbol, string> = {
      ruleRevision: "rule@1",
      source: { identity: "src", revision: "1" },
      coordinate: "c",
      digests: projectionDigests(new Map()),
      residuals: residualSet([symbolic]),
      observations: "d",
      evidence: "e",
    };
    const expected: Expected<string, string, string, string, symbol> = {
      ruleRevision: "rule@1",
      source: { identity: "src", revision: "1" },
      coordinate: "c",
      observations: "d",
      residuals: residualSet([]),
    };
    const built = RuleTable.create([["rule@1", emptyRule as Rule<string, string, string, string, string>]] as const);
    assert.equal(built.ok, true);
    if (!built.ok) return;
    const mismatch = rejected(admit(built.value, certificate, expected, "caller", comparison));
    assert.equal(mismatch.checks.source.kind, "established");
    if (mismatch.checks.source.kind !== "established") return;
    const result = mismatch.checks.source.children.residual;
    assert.equal(result.kind, "mismatched");
    if (result.kind !== "mismatched") return;
    assert.equal(result.failure.expected, "[]");
    assert.equal(result.failure.actual, "[Symbol(residual-a)]");
  });
});
