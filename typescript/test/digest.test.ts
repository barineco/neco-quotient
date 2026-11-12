import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  RuleTable,
  admit,
  check,
  projectionDigests,
  type Certificate,
  type DigestChecks,
  type DigestScope,
  type Expected,
  type ProjectionDigest,
  type Rule,
  residualSet,
} from "../src/index.ts";
import { canonicalJson, conditionsJson, stringComparison } from "./support.ts";

type Cert = Certificate<string, string, string, string, string, string>;
type Exp = Expected<string, string, string, string, string>;

function digest(
  value: string,
  scope: DigestScope = { kind: "cross_language", encoding: "sha256" },
): ProjectionDigest {
  return { digest: value, scope };
}

const graph = digest("aa");
const metadata = digest("bb", { kind: "within_runtime", runtime: "node" });

function recomputedEntries(): [string, ProjectionDigest][] {
  return [
    ["graph", graph],
    ["metadata", metadata],
  ];
}

const rule: Rule<string, string, string, string, string> = () => new Map(recomputedEntries());

function table(item: Rule<string, string, string, string, string> = rule) {
  const built = RuleTable.create([["rule@1", item]] as const);
  if (!built.ok) throw new Error("fixture table has unique revisions");
  return built.value;
}

function certificateWith(digests: Iterable<readonly [string, ProjectionDigest]>): Cert {
  return {
    ruleRevision: "rule@1",
    source: { identity: "src", revision: "1" },
    coordinate: "c",
    digests: projectionDigests(new Map(digests)),
    residuals: residualSet([]),
    observations: "d",
    evidence: "e",
  };
}

const expected: Exp = {
  ruleRevision: "rule@1",
  source: { identity: "src", revision: "1" },
  coordinate: "c",
  observations: "d",
  residuals: residualSet([]),
};

function checksFor(digests: Iterable<readonly [string, ProjectionDigest]>, item = rule) {
  return check(table(item), certificateWith(digests), expected, "caller", stringComparison);
}

function digestChecks(digests: Iterable<readonly [string, ProjectionDigest]>, item = rule): DigestChecks {
  const checks = checksFor(digests, item);
  assert.equal(checks.decode.kind, "established");
  if (checks.decode.kind !== "established") throw new Error("decode is established");
  return checks.decode.children;
}

function summary(digests: DigestChecks): [string, string][] {
  return digests.entries().map(([name, result]) => [name, result.kind]);
}

describe("digest scopes are compared by kind and payload", () => {
  it("accepts the same digests with the same kinds and payloads", () => {
    assert.equal(admit(table(), certificateWith(recomputedEntries()), expected, "caller", stringComparison).ok, true);
  });

  it("reports a cross_language scope whose payload differs as different", () => {
    const result = digestChecks([["graph", digest("aa", { kind: "cross_language", encoding: "sha512" })], ["metadata", metadata]]);
    assert.deepEqual(summary(result), [["graph", "different"], ["metadata", "matched"]]);
  });

  it("reports a within_runtime scope whose runtime differs as different", () => {
    const result = digestChecks([["graph", graph], ["metadata", digest("bb", { kind: "within_runtime", runtime: "deno" })]]);
    assert.deepEqual(summary(result), [["graph", "matched"], ["metadata", "different"]]);
  });

  it("reports a scope whose kind differs as different even when the payload text is equal", () => {
    const result = digestChecks([["graph", graph], ["metadata", digest("bb", { kind: "cross_language", encoding: "node" })]]);
    assert.deepEqual(summary(result), [["graph", "matched"], ["metadata", "different"]]);
  });

  it("keeps the recomputed value as expected and the certificate value as actual", () => {
    const actual = digest("zz");
    const result = digestChecks([["graph", actual], ["metadata", metadata]]).get("graph");
    assert.deepEqual(result, { kind: "different", expected: graph, actual });
  });
});

describe("digests are compared by name, not by position", () => {
  it("accepts the same digests inserted in another order", () => {
    const reversed = [...recomputedEntries()].reverse();
    assert.equal(admit(table(), certificateWith(reversed), expected, "caller", stringComparison).ok, true);
  });

  it("gives the same names, results and output whatever the insertion order is", () => {
    const entries: [string, ProjectionDigest][] = [
      ["graph", graph],
      ["metadata", metadata],
      ["extra", digest("cc")],
      ["\uff5e", digest("dd")],
      ["\u{1f600}", digest("ee")],
    ];
    const forward = checksFor(entries);
    const backward = checksFor([...entries].reverse());
    assert.equal(canonicalJson(conditionsJson(forward)), canonicalJson(conditionsJson(backward)));
    assert.deepEqual(summary(digestChecks(entries)), summary(digestChecks([...entries].reverse())));
    assert.deepEqual(projectionDigests(new Map(entries)).names(), ["extra", "graph", "metadata", "\uff5e", "\u{1f600}"]);
    assert.deepEqual(projectionDigests(new Map([...entries].reverse())).names(), ["extra", "graph", "metadata", "\uff5e", "\u{1f600}"]);
  });

  it("orders names by UTF-8 bytes where UTF-16 code unit order differs", () => {
    const built = projectionDigests({ "\u{1f600}": digest("a"), "\uff5e": digest("b") });
    assert.deepEqual([...built.names()].sort(), ["\u{1f600}", "\uff5e"]);
    assert.deepEqual(built.names(), ["\uff5e", "\u{1f600}"]);
    assert.deepEqual(
      [...built].map(([name]) => name),
      ["\uff5e", "\u{1f600}"],
    );
  });

  it("builds equal maps from a Map and from a record", () => {
    const fromMap = projectionDigests(new Map(recomputedEntries()));
    const fromRecord = projectionDigests({ graph, metadata });
    assert.deepEqual(fromMap.entries(), fromRecord.entries());
  });
});

describe("one-sided names are classified", () => {
  it("reports a name only the certificate has", () => {
    const result = digestChecks([...recomputedEntries(), ["extra", digest("cc")]]);
    assert.deepEqual(summary(result), [["extra", "certificate_only"], ["graph", "matched"], ["metadata", "matched"]]);
    assert.deepEqual(result.get("extra"), { kind: "certificate_only", actual: digest("cc") });
  });

  it("reports a name only the recomputation has", () => {
    const result = digestChecks([["graph", graph]]);
    assert.deepEqual(summary(result), [["graph", "matched"], ["metadata", "recomputed_only"]]);
    assert.deepEqual(result.get("metadata"), { kind: "recomputed_only", expected: metadata });
  });

  it("does not match a projection name that differs", () => {
    const result = digestChecks([["graph2", graph], ["metadata", metadata]]);
    assert.deepEqual(summary(result), [
      ["graph", "recomputed_only"],
      ["graph2", "certificate_only"],
      ["metadata", "matched"],
    ]);
  });

  it("changes only the result of the projection whose digest changed", () => {
    const base = digestChecks(recomputedEntries());
    const changed = digestChecks([["graph", digest("ab")], ["metadata", metadata]]);
    assert.deepEqual(changed.get("metadata"), base.get("metadata"));
    assert.equal(base.get("graph")?.kind, "matched");
    assert.equal(changed.get("graph")?.kind, "different");
  });

  it("mismatches the digest condition for any non-matched name", () => {
    assert.equal(checksFor([["graph", graph]]).statusAt("digest").kind, "mismatched");
    assert.equal(checksFor([...recomputedEntries(), ["extra", graph]]).statusAt("digest").kind, "mismatched");
    assert.equal(checksFor(recomputedEntries()).statusAt("digest").kind, "matched");
  });

  it("matches the digest condition when both maps are empty", () => {
    const empty: Rule<string, string, string, string, string> = () => new Map();
    const checks = checksFor([], empty);
    assert.equal(checks.statusAt("digest").kind, "matched");
    assert.equal(checks.allMatched(), true);
    assert.equal(admit(table(empty), certificateWith([]), expected, "caller", stringComparison).ok, true);
  });
});
