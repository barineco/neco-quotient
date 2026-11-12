import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CONDITIONS, RuleTable, admit, check, conditionPrerequisite, type Condition } from "../src/index.ts";
import {
  CASES_URL,
  COMPARISON_REVISION,
  OUTCOMES_URL,
  RESIDUAL_SET_API_CASES_URL,
  RESIDUAL_SET_API_OUTCOMES_URL,
  canonicalJson,
  canonicalString,
  certificateFromWire,
  comparisonEntries,
  expectedFromWire,
  outcomeJson,
  readBytes,
  readJson,
  sha256Hex,
  stringComparison,
  type CaseRow,
} from "./support.ts";

type OutcomeRow = {
  readonly name: string;
  readonly accepted: boolean;
  readonly residuals: readonly string[];
  readonly conditions: Record<string, { readonly projections?: Record<string, unknown> }>;
};

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

const table = buildTable();

function run(row: CaseRow) {
  const certificate = certificateFromWire(row.certificate);
  const expected = expectedFromWire(row.expected);
  const checks = check(table, certificate, expected, row.provenance, stringComparison);
  const result = admit(table, certificate, expected, row.provenance, stringComparison);
  if (result.ok) {
    assert.equal(checks.allMatched(), true, `${row.name}: admitted although a condition did not match`);
  } else {
    assert.equal(checks.allMatched(), false, `${row.name}: rejected although every condition matched`);
    assert.equal(
      canonicalJson(outcomeJson(row.name, false, result.error.checks, certificate.residuals.values)),
      canonicalJson(outcomeJson(row.name, false, checks, certificate.residuals.values)),
      `${row.name}: the mismatch holds the checks`,
    );
  }
  return { row, certificate, checks, result };
}

const runs = cases.map(run);

function named(name: string) {
  const found = runs.find((item) => item.row.name === name);
  assert.ok(found, `missing case ${name}`);
  return found;
}

function asText(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes);
}

describe("shared certificate admission cases", () => {
  it("has the twenty-one wire cases of the Lean outcomes", () => {
    assert.equal(cases.length, 21);
    assert.deepEqual(
      cases.map((row) => row.name),
      outcomes.map((row) => row.name),
    );
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
      accepted.certificate.digests["evidence"]?.digest,
      sha256Hex(new TextEncoder().encode(canonicalString(accepted.certificate.evidence))),
    );
  });
});

describe("the admission result agrees with the Lean outcomes", () => {
  it("reproduces the conditions and projections of every Lean outcome", () => {
    for (const [index, item] of runs.entries()) {
      const outcome = outcomes[index];
      assert.equal(outcome?.name, item.row.name);
      const actual = outcomeJson(item.row.name, item.result.ok, item.checks, item.certificate.residuals.values);
      assert.deepEqual(JSON.parse(canonicalJson(actual)), outcome, `case ${item.row.name}`);
    }
  });

  it("reproduces the bytes of the Lean outcomes", () => {
    const text = canonicalJson(
      runs.map((item) => outcomeJson(item.row.name, item.result.ok, item.checks, item.certificate.residuals.values)),
    );
    assert.equal(text, asText(readBytes(OUTCOMES_URL)));
  });

  it("reproduces the versioned residual-set API outcomes", () => {
    assert.equal(residualSetApiCases.length, 2);
    const apiRuns = residualSetApiCases.map(run);
    assert.deepEqual(
      apiRuns.map((item) => item.row.name),
      residualSetApiOutcomes.map((row) => row.name),
    );
    const text = canonicalJson(
      apiRuns.map((item) => outcomeJson(item.row.name, item.result.ok, item.checks, item.certificate.residuals.values)),
    );
    assert.equal(text, asText(readBytes(RESIDUAL_SET_API_OUTCOMES_URL)));
    assert.equal(apiRuns[0]?.result.ok, true);
    assert.equal(apiRuns[1]?.result.ok, false);
    assert.equal(apiRuns[1]?.checks.statusAt("residual").kind, "mismatched");
  });

  it("orders the projection names of the output by UTF-8 bytes, not by UTF-16 code units", () => {
    const item = named("digest_utf8_utf16_key_order");
    const names = item.certificate.digests.names();
    assert.deepEqual(names, ["evidence", "\uff5e", "\u{1f600}"]);
    assert.deepEqual([...names].sort(), ["evidence", "\u{1f600}", "\uff5e"]);
    const leanKeys = Object.keys(outcomes[cases.indexOf(item.row)]?.conditions["digest"]?.projections ?? {});
    assert.deepEqual(leanKeys, names);
    assert.equal(item.checks.decode.kind, "established");
    if (item.checks.decode.kind === "established") {
      assert.deepEqual(item.checks.decode.children.names(), names);
    }
  });
});

const ALL = (...words: string[]) => words;

describe("each case reports every condition", () => {
  const expected: [string, string[]][] = [
    ["accepted_plain", ALL("matched", "matched", "matched", "matched", "matched", "matched")],
    ["accepted_unicode_control", ALL("matched", "matched", "matched", "matched", "matched", "matched")],
    ["decode_version", ALL("mismatched", "matched", "matched", "matched", "unchecked", "matched")],
    ["decode_unknown_rule", ALL("mismatched", "matched", "matched", "matched", "unchecked", "matched")],
    ["source_identity", ALL("matched", "mismatched", "unchecked", "unchecked", "matched", "unchecked")],
    ["coordinate", ALL("matched", "matched", "mismatched", "matched", "matched", "matched")],
    ["observations", ALL("matched", "matched", "matched", "mismatched", "matched", "matched")],
    ["digest", ALL("matched", "matched", "matched", "matched", "mismatched", "matched")],
    ["source_with_dependents", ALL("matched", "mismatched", "unchecked", "unchecked", "mismatched", "unchecked")],
    ["both_roots_fail", ALL("mismatched", "mismatched", "unchecked", "unchecked", "unchecked", "unchecked")],
    ["unknown_rule_and_source_fail", ALL("mismatched", "mismatched", "unchecked", "unchecked", "unchecked", "unchecked")],
    ["decode_fail_children_fail", ALL("mismatched", "matched", "mismatched", "mismatched", "unchecked", "mismatched")],
    ["source_and_digest_fail", ALL("matched", "mismatched", "unchecked", "unchecked", "mismatched", "unchecked")],
    ["independent_children_fail", ALL("matched", "matched", "mismatched", "mismatched", "matched", "mismatched")],
    ["all_independent_fail", ALL("matched", "matched", "mismatched", "mismatched", "mismatched", "mismatched")],
    ["digest_names_mixed", ALL("matched", "matched", "matched", "matched", "mismatched", "matched")],
    ["digest_recomputed_only", ALL("matched", "matched", "matched", "matched", "mismatched", "matched")],
    ["digest_value_and_certificate_only", ALL("matched", "matched", "matched", "matched", "mismatched", "matched")],
    ["digest_utf8_utf16_key_order", ALL("matched", "matched", "matched", "matched", "mismatched", "matched")],
    ["digest_key_change_isolated", ALL("matched", "matched", "matched", "matched", "mismatched", "matched")],
    ["digest_keys_both_sides", ALL("matched", "matched", "matched", "matched", "mismatched", "matched")],
  ];
  const statusWord = (kind: string) => (kind.startsWith("unchecked") ? "unchecked" : kind);

  it("covers every case of the corpus", () => {
    assert.deepEqual(
      expected.map(([name]) => name),
      cases.map((row) => row.name),
    );
  });

  for (const [name, words] of expected) {
    it(`${name}: ${words.join(" ")}`, () => {
      const item = named(name);
      assert.deepEqual(
        CONDITIONS.map((condition) => statusWord(item.checks.statusAt(condition).kind)),
        words,
      );
    });
  }

  it("holds unchecked exactly when the prerequisite condition is mismatched", () => {
    for (const item of runs) {
      for (const condition of CONDITIONS) {
        const status = item.checks.statusAt(condition);
        const unchecked = status.kind === "unchecked_by_decode" || status.kind === "unchecked_by_source";
        if (status.kind === "unchecked_by_decode") assert.equal(condition, "digest", item.row.name);
        const prerequisite: Condition | undefined = conditionPrerequisite(condition);
        if (prerequisite === undefined) {
          assert.equal(unchecked, false, `${item.row.name} ${condition}`);
        } else {
          assert.equal(
            unchecked,
            item.checks.statusAt(prerequisite).kind === "mismatched",
            `${item.row.name} ${condition}`,
          );
        }
      }
    }
  });
});

describe("projection results classify one-sided and differing names", () => {
  const expected: [string, [string, string][]][] = [
    ["accepted_plain", [["evidence", "matched"]]],
    ["digest", [["evidence", "different"]]],
    ["digest_names_mixed", [["alpha", "certificate_only"], ["evidence", "different"], ["zeta", "certificate_only"]]],
    ["digest_recomputed_only", [["evidence", "recomputed_only"]]],
    [
      "digest_value_and_certificate_only",
      [["evidence", "different"], ["extra-one", "certificate_only"], ["extra-two", "certificate_only"]],
    ],
    ["digest_utf8_utf16_key_order", [["evidence", "matched"], ["\uff5e", "certificate_only"], ["\u{1f600}", "certificate_only"]]],
    ["digest_key_change_isolated", [["evidence", "matched"], ["other", "certificate_only"]]],
    ["digest_keys_both_sides", [["evidence", "recomputed_only"], ["extra", "certificate_only"]]],
  ];
  for (const [name, kinds] of expected) {
    it(name, () => {
      const { checks } = named(name);
      assert.equal(checks.decode.kind, "established");
      if (checks.decode.kind !== "established") return;
      assert.deepEqual(
        checks.decode.children.entries().map(([projection, result]) => [projection, result.kind]),
        kinds,
      );
    });
  }

  it("changes only the result of the projection whose value changed", () => {
    const base = named("accepted_plain");
    const changed = named("digest");
    if (base.checks.decode.kind !== "established" || changed.checks.decode.kind !== "established") {
      throw new Error("decode is established");
    }
    assert.deepEqual(base.checks.decode.children.names(), changed.checks.decode.children.names());
    assert.equal(base.checks.decode.children.get("evidence")?.kind, "matched");
    assert.equal(changed.checks.decode.children.get("evidence")?.kind, "different");
  });
});

describe("decode failures distinguish the version mismatch and the unknown revision", () => {
  it("reports the expected revision for a version mismatch", () => {
    const { checks } = named("decode_version");
    assert.equal(checks.decode.kind, "failed");
    if (checks.decode.kind !== "failed") return;
    assert.equal(checks.decode.failure.condition, "decode");
    assert.equal(checks.decode.failure.expected, "comparison/sha256@2");
    assert.equal(checks.decode.failure.actual, "comparison/sha256@1");
  });

  it("reports the table expectation for an unknown revision that agrees", () => {
    const { checks } = named("decode_unknown_rule");
    assert.equal(checks.decode.kind, "failed");
    if (checks.decode.kind !== "failed") return;
    assert.equal(checks.decode.failure.expected, "rule in table");
    assert.equal(checks.decode.failure.actual, "comparison/sha256@9");
  });
});

describe("every failure keeps the input provenance and the certificate origin", () => {
  it("counts the failing and accepted cases", () => {
    assert.equal(runs.filter((item) => !item.result.ok).length, 19);
    assert.equal(runs.filter((item) => item.result.ok).length, 2);
  });

  for (const item of runs) {
    if (item.result.ok) continue;
    const mismatch = item.result.error;
    it(`keeps the caller provenance of ${item.row.name}`, () => {
      assert.equal(mismatch.provenance, item.row.provenance);
      assert.equal(mismatch.provenance, `caller/${item.row.name}`);
      assert.deepEqual(mismatch.origin, {
        ruleRevision: item.certificate.ruleRevision,
        sourceIdentity: item.certificate.source.identity,
        sourceRevision: item.certificate.source.revision,
      });
      const { checks } = item;
      const failures = [
        checks.decode.kind === "failed" ? checks.decode.failure : undefined,
        checks.source.kind === "failed" ? checks.source.failure : undefined,
        ...(checks.source.kind === "established"
          ? [checks.source.children.coordinate, checks.source.children.observations, checks.source.children.residual].map(
              (result) => (result.kind === "mismatched" ? result.failure : undefined),
            )
          : []),
      ].filter((failure) => failure !== undefined);
      if (failures.length === 0) {
        assert.equal(checks.statusAt("digest").kind, "mismatched", "a failure without a record is a digest mismatch");
      }
      for (const failure of failures) {
        assert.equal(failure.provenance, item.row.provenance);
        assert.deepEqual(failure.origin, mismatch.origin);
        assert.equal(failure.operation, "admit");
      }
    });
  }

  it("returns the certificate and the recomputed digests of an accepted case", () => {
    for (const item of runs) {
      if (!item.result.ok) continue;
      assert.deepEqual(item.result.value.certificate, item.certificate);
      assert.deepEqual(item.result.value.recomputed.entries(), item.certificate.digests.entries());
    }
  });
});
