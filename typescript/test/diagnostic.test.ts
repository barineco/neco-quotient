import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  RuleTable,
  admit,
  type Certificate,
  type Comparison,
  type Expected,
  type ProjectionDigest,
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

const emptyRule: Rule<string, string, Coordinate, string, string> = () => [];

function table() {
  const built = RuleTable.create([["rule@1", emptyRule]] as const);
  if (!built.ok) throw new Error("fixture table has unique revisions");
  return built.value;
}

describe("a coordinate with a self reference is reported as a mismatch", () => {
  it("uses the standard string form of the coordinate values at the coordinate stage", () => {
    const comparison: Comparison<string, string, Coordinate, string, string> = {
      ...stringComparison,
      sameCoordinate: (left, right) => Object.is(left, right),
    };
    const expectedCoordinate = new Coordinate("expected-label");
    const actualCoordinate = new Coordinate("actual-label");
    const certificate: Cert = {
      ruleRevision: "rule@1",
      source: { identity: "src", revision: "1" },
      coordinate: actualCoordinate,
      digests: [],
      residuals: residualSet([]),
      observations: "d",
      evidence: "e",
    };
    const expected: Exp = {
      ruleRevision: "rule@1",
      source: { identity: "src", revision: "1" },
      coordinate: expectedCoordinate,
      observations: "d",
      residuals: residualSet([]),
    };
    const result = admit(table(), certificate, expected, "caller", comparison);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.stage, "coordinate");
    assert.equal(result.error.expected, "expected-label");
    assert.equal(result.error.actual, "actual-label");
    assert.equal(result.error.provenance, "caller");
  });
});

describe("digest and residual lists are reported with their actual fields", () => {
  it("shows the projection, digest and scope payload of each digest", () => {
    const digests: ProjectionDigest[] = [
      { projection: "graph", digest: "aa", scope: { kind: "cross_language", encoding: "sha256" } },
      { projection: "metadata", digest: "bb", scope: { kind: "within_runtime", runtime: "node" } },
    ];
    const rule: Rule<string, string, string, string, string> = () => digests;
    const built = RuleTable.create([["rule@1", rule]] as const);
    assert.equal(built.ok, true);
    if (!built.ok) return;
    const certificate = {
      ruleRevision: "rule@1",
      source: { identity: "src", revision: "1" },
      coordinate: "c",
      digests: [],
      residuals: residualSet([]),
      observations: "d",
      evidence: "e",
    };
    const expected = {
      ruleRevision: "rule@1",
      source: { identity: "src", revision: "1" },
      coordinate: "c",
      observations: "d",
      residuals: residualSet([]),
    };
    const result = admit(built.value, certificate, expected, "caller", stringComparison);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.stage, "digest");
    assert.equal(
      result.error.expected,
      "[{projection: graph, digest: aa, scope: cross_language:sha256}, {projection: metadata, digest: bb, scope: within_runtime:node}]",
    );
    assert.equal(result.error.actual, "[]");
  });

  it("renders a symbol residual through its standard string form", () => {
    const built = RuleTable.create([["rule@1", emptyRule as Rule<string, string, string, string, string>]] as const);
    assert.equal(built.ok, true);
    if (!built.ok) return;
    const symbolic = Symbol("residual-a");
    const comparison: Comparison<string, string, string, string, symbol> = {
      ...stringComparison,
      sameResidual: (left, right) => left === right,
    };
    const certificate: Certificate<string, string, string, string, symbol, string> = {
      ruleRevision: "rule@1",
      source: { identity: "src", revision: "1" },
      coordinate: "c",
      digests: [],
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
    const result = admit(built.value, certificate, expected, "caller", comparison);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.stage, "residual");
    assert.equal(result.error.actual, "[Symbol(residual-a)]");
  });
});
