import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  RuleTable,
  admit,
  type Certificate,
  type DigestScope,
  type Expected,
  type ProjectionDigest,
  type Rule,
  residualSet,
} from "../src/index.ts";
import { stringComparison } from "./support.ts";

type Cert = Certificate<string, string, string, string, string, string>;
type Exp = Expected<string, string, string, string, string>;

function digest(
  projection: string,
  value: string,
  scope: DigestScope = { kind: "cross_language", encoding: "sha256" },
): ProjectionDigest {
  return { projection, digest: value, scope };
}

const baseDigests: readonly [ProjectionDigest, ProjectionDigest] = [
  digest("graph", "aa"),
  digest("metadata", "bb", { kind: "within_runtime", runtime: "node" }),
];

const rule: Rule<string, string, string, string, string> = () => baseDigests;

function table() {
  const built = RuleTable.create([["rule@1", rule]] as const);
  if (!built.ok) throw new Error("fixture table has unique revisions");
  return built.value;
}

function certificateWith(digests: ProjectionDigest[]): Cert {
  return {
    ruleRevision: "rule@1",
    source: { identity: "src", revision: "1" },
    coordinate: "c",
    digests,
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

function admitDigests(digests: ProjectionDigest[]) {
  return admit(table(), certificateWith(digests), expected, "caller", stringComparison);
}

describe("digest scopes are compared by kind and payload", () => {
  it("accepts the same digest list with the same kinds and payloads", () => {
    assert.equal(admitDigests([digest("graph", "aa"), digest("metadata", "bb", { kind: "within_runtime", runtime: "node" })]).ok, true);
  });

  it("rejects a cross_language scope whose payload differs", () => {
    const result = admitDigests([
      digest("graph", "aa", { kind: "cross_language", encoding: "sha512" }),
      baseDigests[1],
    ]);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.stage, "digest");
  });

  it("rejects a within_runtime scope whose runtime differs", () => {
    const result = admitDigests([
      digest("graph", "aa"),
      digest("metadata", "bb", { kind: "within_runtime", runtime: "deno" }),
    ]);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.stage, "digest");
  });

  it("rejects a scope whose kind differs even when the payload text is equal", () => {
    const result = admitDigests([
      digest("graph", "aa"),
      digest("metadata", "bb", { kind: "cross_language", encoding: "node" }),
    ]);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.stage, "digest");
  });
});

describe("digest lists are compared in order, length, and every field", () => {
  it("rejects the same digests in another order", () => {
    const result = admitDigests([baseDigests[1], baseDigests[0]]);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.stage, "digest");
  });

  it("rejects a shorter list and a longer list", () => {
    const shorter = admitDigests([digest("graph", "aa")]);
    const longer = admitDigests([...baseDigests, digest("extra", "cc")]);
    assert.equal(shorter.ok, false);
    assert.equal(longer.ok, false);
  });

  it("rejects a differing projection name or digest text", () => {
    assert.equal(admitDigests([digest("graph2", "aa"), baseDigests[1]]).ok, false);
    assert.equal(admitDigests([digest("graph", "ab"), baseDigests[1]]).ok, false);
  });

  it("accepts the empty list when the rule recomputes an empty list", () => {
    const empty: Rule<string, string, string, string, string> = () => [];
    const built = RuleTable.create([["rule@1", empty]] as const);
    assert.equal(built.ok, true);
    if (!built.ok) return;
    const result = admit(built.value, certificateWith([]), expected, "caller", stringComparison);
    assert.equal(result.ok, true);
  });
});
