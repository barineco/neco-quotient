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
  projectionDigests,
  residualSet,
} from "../src/index.ts";

type Identity = { readonly id: number };
type Coordinate = readonly [number, number];
type Evidence = Uint8Array;

type Cert = Certificate<Identity, bigint, Coordinate, boolean, symbol, Evidence>;
type Exp = Expected<Identity, bigint, Coordinate, boolean, symbol>;

const residualA = Symbol("residual-a");
const residualB = Symbol("residual-b");

const rule: Rule<Identity, bigint, Coordinate, boolean, Evidence> = (source, coordinate, observations, evidence) => {
  const digest: ProjectionDigest = {
    digest: `${source.identity.id}:${String(source.revision)}:${coordinate[0]},${coordinate[1]}:${String(observations)}:${evidence.join(".")}`,
    scope: { kind: "within_runtime", runtime: "node" },
  };
  return { payload: digest };
};

const comparison: Comparison<Identity, bigint, Coordinate, boolean, symbol> = {
  sameSource: (left, right) => left.id === right.id,
  sameRevision: (left, right) => left === right,
  sameCoordinate: (left, right) => left[0] === right[0] && left[1] === right[1],
  sameObservations: (left, right) => left === right,
  sameResidual: (left, right) => left === right,
  identityText: (identity) => `id:${identity.id}`,
  revisionText: (revision) => `r${revision.toString()}`,
};

function table() {
  const built = RuleTable.create([["rule@1", rule]] as const);
  if (!built.ok) throw new Error("fixture table has unique revisions");
  return built.value;
}

function certificate(): Cert {
  const source = { identity: { id: 7 }, revision: 11n };
  const evidence = new Uint8Array([1, 2, 3]);
  return {
    ruleRevision: "rule@1",
    source,
    coordinate: [4, 5],
    digests: projectionDigests(rule(source, [4, 5], true, evidence)),
    residuals: residualSet([residualA]),
    observations: true,
    evidence,
  };
}

function expected(): Exp {
  return {
    ruleRevision: "rule@1",
    source: { identity: { id: 7 }, revision: 11n },
    coordinate: [4, 5],
    observations: true,
    residuals: residualSet([residualA]),
  };
}

describe("admit accepts identity, revision, coordinate, observations and residuals that are not strings", () => {
  it("returns the checked value with the non-string source and recomputed payload digests", () => {
    const result = admit(table(), certificate(), expected(), { caller: 1 }, comparison);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.value.source, { identity: { id: 7 }, revision: 11n });
    assert.equal(result.value.recomputed.get("payload")?.digest, "7:11:4,5:true:1.2.3");
  });

  it("reports a bigint revision difference at source with origin rendered by the caller", () => {
    const shifted = { ...certificate(), source: { identity: { id: 7 }, revision: 12n } };
    const result = admit(table(), shifted, expected(), "caller", comparison);
    assert.equal(result.ok, false);
    if (result.ok) return;
    const source = result.error.checks.source;
    assert.equal(source.kind, "failed");
    if (source.kind !== "failed") return;
    assert.equal(source.failure.expected, "id:7@r11");
    assert.equal(source.failure.actual, "id:7@r12");
    assert.deepEqual(result.error.origin, { ruleRevision: "rule@1", sourceIdentity: "id:7", sourceRevision: "r12" });
  });

  it("compares symbol residuals by the caller equality and reports them at residual", () => {
    const changed = { ...certificate(), residuals: residualSet([residualB]) };
    const result = admit(table(), changed, expected(), "caller", comparison);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.statusAt("residual").kind, "mismatched");
    assert.equal(result.error.statusAt("source").kind, "matched");
  });
});

type Ordinal = { readonly ordinal: bigint };
type Enabled = { readonly enabled: boolean };
type Code = { readonly code: string };

type RecordCert = Certificate<Identity, Ordinal, Coordinate, Enabled, Code, Evidence>;
type RecordExp = Expected<Identity, Ordinal, Coordinate, Enabled, Code>;

const recordRule: Rule<Identity, Ordinal, Coordinate, Enabled, Evidence> = (source, coordinate, observations, evidence) => ({
  record: {
    digest: `${source.identity.id}:${source.revision.ordinal.toString()}:${coordinate[0]},${coordinate[1]}:${String(observations.enabled)}:${evidence.join(".")}`,
    scope: { kind: "within_runtime", runtime: "node" },
  },
});

const recordComparison: Comparison<Identity, Ordinal, Coordinate, Enabled, Code> = {
  sameSource: (left, right) => left.id === right.id,
  sameRevision: (left, right) => left.ordinal === right.ordinal,
  sameCoordinate: (left, right) => left[0] === right[0] && left[1] === right[1],
  sameObservations: (left, right) => left.enabled === right.enabled,
  sameResidual: (left, right) => left.code === right.code,
  identityText: (identity) => `id:${identity.id}`,
  revisionText: (revision) => `o${revision.ordinal.toString()}`,
};

function recordTable() {
  const built = RuleTable.create([["rule@1", recordRule]] as const);
  if (!built.ok) throw new Error("fixture table has unique revisions");
  return built.value;
}

function recordCertificate(ordinal: bigint, enabled: boolean, code: string): RecordCert {
  const coordinate: Coordinate = [4, 5];
  const observations = { enabled };
  const evidence = new Uint8Array([1, 2, 3]);
  const source = { identity: { id: 7 }, revision: { ordinal } };
  return {
    ruleRevision: "rule@1",
    source,
    coordinate,
    digests: projectionDigests(recordRule(source, coordinate, observations, evidence)),
    residuals: residualSet([{ code }]),
    observations,
    evidence,
  };
}

function recordExpected(ordinal: bigint, enabled: boolean, code: string): RecordExp {
  return {
    ruleRevision: "rule@1",
    source: { identity: { id: 7 }, revision: { ordinal } },
    coordinate: [4, 5],
    observations: { enabled },
    residuals: residualSet([{ code }]),
  };
}

describe("admit compares record revision, observations and residual by the value of their single field", () => {
  it("accepts distinct instances with equal field values and rejects each differing field at its condition", () => {
    const accepted = admit(recordTable(), recordCertificate(11n, true, "a"), recordExpected(11n, true, "a"), "caller", recordComparison);
    assert.equal(accepted.ok, true);
    if (accepted.ok) assert.equal(accepted.value.recomputed.get("record")?.digest, "7:11:4,5:true:1.2.3");

    const revision = admit(recordTable(), recordCertificate(12n, true, "a"), recordExpected(11n, true, "a"), "caller", recordComparison);
    assert.equal(revision.ok, false);
    if (!revision.ok) {
      assert.equal(revision.error.checks.source.kind, "failed");
      if (revision.error.checks.source.kind === "failed") {
        assert.equal(revision.error.checks.source.failure.expected, "id:7@o11");
        assert.equal(revision.error.checks.source.failure.actual, "id:7@o12");
      }
    }

    const observations = admit(recordTable(), recordCertificate(11n, false, "a"), recordExpected(11n, true, "a"), "caller", recordComparison);
    assert.equal(observations.ok, false);
    if (!observations.ok) assert.equal(observations.error.statusAt("observations").kind, "mismatched");

    const residual = admit(recordTable(), recordCertificate(11n, true, "b"), recordExpected(11n, true, "a"), "caller", recordComparison);
    assert.equal(residual.ok, false);
    if (!residual.ok) assert.equal(residual.error.statusAt("residual").kind, "mismatched");
  });
});
