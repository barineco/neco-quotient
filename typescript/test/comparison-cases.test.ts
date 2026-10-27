import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { RuleTable, admit } from "../src/index.ts";
import {
  CASES_URL,
  COMPARISON_REVISION,
  OUTCOMES_URL,
  RESIDUAL_SET_API_CASES_URL,
  RESIDUAL_SET_API_OUTCOMES_URL,
  canonicalString,
  certificateFromWire,
  comparisonEntries,
  expectedFromWire,
  readJson,
  sha256Hex,
  stringComparison,
  type CaseRow,
  type OutcomeRow,
} from "./support.ts";

const cases = readJson<CaseRow[]>(CASES_URL);
const outcomes = readJson<OutcomeRow[]>(OUTCOMES_URL);
const residualSetApiCases = readJson<CaseRow[]>(RESIDUAL_SET_API_CASES_URL);
const residualSetApiOutcomes = readJson<OutcomeRow[]>(RESIDUAL_SET_API_OUTCOMES_URL);

function buildTable() {
  const built = RuleTable.create(comparisonEntries());
  assert.equal(built.ok, true);
  if (!built.ok) throw new Error("the comparison table is built");
  return built.value;
}

describe("shared certificate admission cases", () => {
  it("has the nine wire cases with the stage coverage of the Lean outcomes", () => {
    assert.equal(cases.length, 9);
    assert.deepEqual(
      cases.map((row) => row.name),
      outcomes.map((row) => row.name),
    );
    const stages = outcomes.map((row) => row.failure?.stage ?? "accepted");
    const counts = stages.reduce<Record<string, number>>((acc, stage) => {
      acc[stage] = (acc[stage] ?? 0) + 1;
      return acc;
    }, {});
    assert.deepEqual(counts, {
      accepted: 2,
      decode: 2,
      source: 2,
      coordinate: 1,
      observations: 1,
      digest: 1,
    });
  });

  it("uses the comparison revision for every case", () => {
    for (const row of cases) {
      assert.equal(row.certificate.rule_revision.startsWith("comparison/sha256@"), true, row.name);
    }
    assert.equal(COMPARISON_REVISION, "comparison/sha256@1");
  });

  it("escapes the evidence as a canonical JSON string before hashing it", () => {
    assert.equal(canonicalString(""), '""');
    assert.equal(canonicalString('a"\\\n\r\t\b\f\u0001/\u007f日'), '"a\\"\\\\\\n\\r\\t\\b\\f\\u0001/\u007f日"');
    const accepted = cases.find((row) => row.name === "accepted_plain");
    assert.ok(accepted, "the shared corpus has accepted_plain");
    assert.equal(
      accepted.certificate.digests[0]?.digest,
      sha256Hex(new TextEncoder().encode(canonicalString(accepted.certificate.evidence))),
    );
  });
});

describe("versioned residual-set API cases", () => {
  const table = buildTable();

  it("compares order and duplicates separately from the wire corpus", () => {
    assert.equal(residualSetApiCases.length, 2);
    assert.deepEqual(
      residualSetApiCases.map((row) => row.name),
      residualSetApiOutcomes.map((row) => row.name),
    );
    for (const [index, row] of residualSetApiCases.entries()) {
      const outcome = residualSetApiOutcomes[index];
      assert.ok(outcome, `outcome of ${row.name}`);
      const result = admit(
        table,
        certificateFromWire(row.certificate),
        expectedFromWire(row.expected),
        row.provenance,
        stringComparison,
      );
      assert.equal(result.ok, outcome.accepted, `accepted of ${row.name}`);
      assert.deepEqual(
        outcome.residuals,
        [...certificateFromWire(row.certificate).residuals.values].sort(),
      );
      if (result.ok) continue;
      assert.equal(result.error.operation, outcome.failure?.operation);
      assert.equal(result.error.stage, outcome.failure?.stage);
      assert.deepEqual(result.error.origin, {
        ruleRevision: outcome.failure?.origin.rule_revision,
        sourceIdentity: outcome.failure?.origin.source_identity,
        sourceRevision: outcome.failure?.origin.source_revision,
      });
      assert.equal(result.error.provenance, row.provenance);
      assert.deepEqual(result.error.contributing, []);
    }
    assert.equal(residualSetApiOutcomes[0]?.accepted, true);
    assert.equal(residualSetApiOutcomes[1]?.failure?.stage, "residual");
  });
});

describe("admit agrees with the Lean outcomes for each shared case", () => {
  const table = buildTable();
  for (const [index, row] of cases.entries()) {
    it(row.name, () => {
      const outcome = outcomes[index];
      assert.equal(outcome?.name, row.name);
      const result = admit(
        table,
        certificateFromWire(row.certificate),
        expectedFromWire(row.expected),
        row.provenance,
        stringComparison,
      );
      assert.equal(result.ok, outcome?.accepted, `accepted of ${row.name}`);
      assert.deepEqual(
        outcome?.residuals,
        [...certificateFromWire(row.certificate).residuals.values].sort(),
      );
      if (result.ok) {
        assert.deepEqual(result.value.recomputed, [
          {
            projection: "evidence",
            digest: row.certificate.digests[0]?.digest,
            scope: { kind: "cross_language", encoding: "sha256" },
          },
        ]);
        return;
      }
      const failure = outcome?.failure;
      assert.ok(failure, `Lean failure of ${row.name}`);
      const mismatch = result.error;
      assert.equal(mismatch.operation, failure.operation);
      assert.equal(mismatch.stage, failure.stage);
      assert.deepEqual(mismatch.origin, {
        ruleRevision: failure.origin.rule_revision,
        sourceIdentity: failure.origin.source_identity,
        sourceRevision: failure.origin.source_revision,
      });
      assert.equal(mismatch.provenance, row.provenance);
      assert.deepEqual(mismatch.contributing, []);
    });
  }
});

describe("decode failures distinguish the version mismatch and the unknown revision", () => {
  const table = buildTable();
  it("reports the expected revision for a version mismatch", () => {
    const row = cases.find((item) => item.name === "decode_version");
    assert.ok(row);
    const result = admit(
      table,
      certificateFromWire(row.certificate),
      expectedFromWire(row.expected),
      row.provenance,
      stringComparison,
    );
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.expected, "comparison/sha256@2");
    assert.equal(result.error.actual, "comparison/sha256@1");
  });
  it("reports the table expectation for an unknown revision that agrees", () => {
    const row = cases.find((item) => item.name === "decode_unknown_rule");
    assert.ok(row);
    const result = admit(
      table,
      certificateFromWire(row.certificate),
      expectedFromWire(row.expected),
      row.provenance,
      stringComparison,
    );
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.expected, "rule in table");
    assert.equal(result.error.actual, "comparison/sha256@9");
  });
});

describe("provenance of every failing case is the input provenance", () => {
  const table = buildTable();
  const failing = cases.filter((row) => outcomes.find((item) => item.name === row.name)?.accepted === false);
  it("counts seven failing cases", () => {
    assert.equal(failing.length, 7);
  });
  for (const row of failing) {
    it(`keeps the caller provenance of ${row.name}`, () => {
      const result = admit(
        table,
        certificateFromWire(row.certificate),
        expectedFromWire(row.expected),
        row.provenance,
        stringComparison,
      );
      assert.equal(result.ok, false);
      if (result.ok) return;
      assert.equal(result.error.provenance, `caller/${row.name}`);
      assert.equal(result.error.provenance, row.provenance);
    });
  }
});
