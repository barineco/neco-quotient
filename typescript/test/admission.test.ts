import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  CONDITIONS,
  Checked,
  Mismatch,
  NameMap,
  RuleTable,
  admit,
  check,
  projectionDigests,
  type Certificate,
  type Comparison,
  type Condition,
  type Expected,
  type ProjectionDigest,
  type ProjectionDigestsInput,
  type Result,
  type Rule,
  residualSet,
} from "../src/index.ts";
import { stringComparison } from "./support.ts";

type Cert = Certificate<string, string, string, string, string, string>;
type Exp = Expected<string, string, string, string, string>;

let calls = 0;

function digestsFor(
  _source: { identity: string; revision: string },
  _coordinate: string,
  _observations: string,
  evidence: string,
  salt = "default",
): Map<string, ProjectionDigest> {
  return new Map(
    ["graph", "metadata"].map((projection) => [
      projection,
      {
        digest: `${salt}|${projection}|${evidence}`,
        scope: { kind: "cross_language", encoding: "fnv1a-64" },
      } satisfies ProjectionDigest,
    ]),
  );
}

const rule: Rule<string, string, string, string, string> = (source, coordinate, observations, evidence) => {
  calls += 1;
  return digestsFor(source, coordinate, observations, evidence);
};

function table(entries = [["rule@1", rule]] as const) {
  const built = RuleTable.create(entries.map(([revision, item]) => [revision, item] as const));
  if (!built.ok) throw new Error("fixture table has unique revisions");
  return built.value;
}

const SOURCE = { identity: "src", revision: "7" };

function fixtureCertificate(): Cert {
  return {
    ruleRevision: "rule@1",
    source: { ...SOURCE },
    coordinate: "c1",
    digests: projectionDigests(digestsFor(SOURCE, "c1", "d3", "e5")),
    residuals: residualSet(["r2"]),
    observations: "d3",
    evidence: "e5",
  };
}

function fixtureExpected(): Exp {
  return {
    ruleRevision: "rule@1",
    source: { ...SOURCE },
    coordinate: "c1",
    observations: "d3",
    residuals: residualSet(["r2"]),
  };
}

function breakCondition(certificate: Cert, condition: Condition): Cert {
  switch (condition) {
    case "decode":
      return { ...certificate, ruleRevision: "rule@2" };
    case "source":
      return { ...certificate, source: { identity: "src", revision: "8" } };
    case "coordinate":
      return { ...certificate, coordinate: "c9" };
    case "observations":
      return { ...certificate, observations: "d9" };
    case "digest":
      return { ...certificate, digests: projectionDigests(digestsFor(SOURCE, "c1", "d3", "e5", "other")) };
    case "residual":
      return { ...certificate, residuals: residualSet(["r9"]) };
  }
}

function breakAll(conditions: readonly Condition[]): Cert {
  return conditions.reduce(breakCondition, fixtureCertificate());
}

function rejected(result: Result<unknown, Mismatch<unknown>>): Mismatch<unknown> {
  assert.equal(result.ok, false, "the certificate is rejected");
  if (result.ok) throw new Error("unreachable");
  return result.error;
}

function kinds(mismatch: Mismatch<unknown>): string[] {
  return CONDITIONS.map((condition) => {
    const kind = mismatch.statusAt(condition).kind;
    return kind.startsWith("unchecked") ? "unchecked" : kind;
  });
}

function admitBroken(conditions: readonly Condition[]): Mismatch<unknown> {
  return rejected(admit(table(), breakAll(conditions), fixtureExpected(), "caller", stringComparison));
}

describe("the rule receives the certificate fields", () => {
  it("passes the source, coordinate, observations and evidence of the certificate", () => {
    let received: unknown[] = [];
    const spy: Rule<string, string, string, string, string> = (source, coordinate, observations, evidence) => {
      received = [source, coordinate, observations, evidence];
      return digestsFor(source, coordinate, observations, evidence);
    };
    admit(table([["rule@1", spy]] as const), fixtureCertificate(), fixtureExpected(), "caller", stringComparison);
    assert.deepEqual(received, [SOURCE, "c1", "d3", "e5"]);
  });
});

describe("admit accepts a consistent certificate", () => {
  it("returns a checked value with the certificate, the expected value and the recomputed digests", () => {
    const result = admit(table(), fixtureCertificate(), fixtureExpected(), "caller", stringComparison);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.ok(result.value instanceof Checked);
    assert.deepEqual(result.value.certificate, fixtureCertificate());
    assert.deepEqual(result.value.expected, fixtureExpected());
    assert.deepEqual(result.value.source, SOURCE);
    assert.deepEqual(
      result.value.recomputed.entries(),
      projectionDigests(digestsFor(SOURCE, "c1", "d3", "e5")).entries(),
    );
    assert.equal(
      check(table(), fixtureCertificate(), fixtureExpected(), "caller", stringComparison).allMatched(),
      true,
    );
  });

  it("freezes the recomputed digests and the copied certificate outer values", () => {
    const certificate = fixtureCertificate();
    const result = admit(table(), certificate, fixtureExpected(), "caller", stringComparison);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(Object.isFrozen(result.value.recomputed), true);
    assert.equal(Object.isFrozen(result.value.certificate.digests), true);
    assert.equal(Object.isFrozen(result.value.certificate.residuals), true);
    assert.equal(Object.isFrozen(result.value.certificate.source), true);
    assert.equal(Object.isFrozen(result.value.expected.source), true);
    assert.notEqual(result.value.certificate.digests, certificate.digests);
  });

  it("does not change the checked value when the caller mutates its inputs afterwards", () => {
    const residuals = ["r2"];
    const certificate = { ...fixtureCertificate(), residuals: residualSet(residuals) };
    const result = admit(table(), certificate, fixtureExpected(), "caller", stringComparison);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    residuals.push("r9");
    (certificate as { ruleRevision: string }).ruleRevision = "rule@2";
    assert.deepEqual(result.value.certificate.residuals.values, ["r2"]);
    assert.equal(result.value.certificate.ruleRevision, "rule@1");
  });
});

describe("the digest map is copied at every public boundary", () => {
  it("does not follow a caller Map that changes after the map is built", () => {
    const input = digestsFor(SOURCE, "c1", "d3", "e5");
    const built = projectionDigests(input);
    input.set("extra", { digest: "x", scope: { kind: "within_runtime", runtime: "node" } });
    input.delete("graph");
    assert.deepEqual(built.names(), ["graph", "metadata"]);
  });

  it("does not follow a caller record or a caller digest value that changes afterwards", () => {
    const value = { digest: "aa", scope: { kind: "cross_language" as const, encoding: "sha256" } };
    const record: Record<string, ProjectionDigest> = { graph: value };
    const built = projectionDigests(record);
    record["extra"] = value;
    (value as { digest: string }).digest = "bb";
    (value.scope as { encoding: string }).encoding = "other";
    assert.deepEqual(built.names(), ["graph"]);
    assert.deepEqual(built.get("graph"), { digest: "aa", scope: { kind: "cross_language", encoding: "sha256" } });
    assert.equal(Object.isFrozen(built.get("graph")), true);
    assert.equal(Object.isFrozen(built.get("graph")?.scope), true);
  });

  it("does not follow a rule result that the rule changes after admission", () => {
    const shared = digestsFor(SOURCE, "c1", "d3", "e5");
    const sharing: Rule<string, string, string, string, string> = () => shared;
    const result = admit(table([["rule@1", sharing]] as const), fixtureCertificate(), fixtureExpected(), "caller", stringComparison);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    shared.delete("graph");
    assert.deepEqual(result.value.recomputed.names(), ["graph", "metadata"]);
  });

  it("copies a record returned by a rule", () => {
    const record: Record<string, ProjectionDigest> = Object.fromEntries(digestsFor(SOURCE, "c1", "d3", "e5"));
    const recordRule: Rule<string, string, string, string, string> = () => record;
    const result = admit(table([["rule@1", recordRule]] as const), fixtureCertificate(), fixtureExpected(), "caller", stringComparison);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    delete record["graph"];
    assert.deepEqual(result.value.recomputed.names(), ["graph", "metadata"]);
  });

  it("copies the digests of a certificate whose map the caller built from a Map", () => {
    const certificate = fixtureCertificate();
    const result = admit(table(), certificate, fixtureExpected(), "caller", stringComparison);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.notEqual(result.value.certificate.digests, certificate.digests);
    assert.deepEqual(result.value.certificate.digests.entries(), certificate.digests.entries());
  });

  it("exposes no operation that updates the map", () => {
    const built = projectionDigests(digestsFor(SOURCE, "c1", "d3", "e5"));
    const surface = new Set<string>();
    for (let prototype: object | null = built; prototype !== null; prototype = Object.getPrototypeOf(prototype)) {
      for (const key of Reflect.ownKeys(prototype)) surface.add(String(key));
    }
    for (const update of ["set", "delete", "clear", "add", "push", "sort"]) {
      assert.equal(surface.has(update), false, update);
    }
    assert.equal(Object.isFrozen(built), true);
    assert.ok(built instanceof NameMap);
    const names = built.names() as string[];
    assert.throws(() => names.push("x"), TypeError);
    assert.deepEqual(built.names(), ["graph", "metadata"]);
  });

  it("rejects an input that is neither a Map, a NameMap nor a plain record", () => {
    class Foreign extends Map<string, ProjectionDigest> {}
    assert.equal(projectionDigests(new Foreign()).size, 0);
    assert.throws(() => projectionDigests(new (class {})() as unknown as ProjectionDigestsInput), TypeError);
  });
});

describe("admit reports every failing condition whose prerequisite holds", () => {
  it("reports each condition alone and leaves the others matched", () => {
    const expectedKinds: Record<Condition, string[]> = {
      decode: ["mismatched", "matched", "matched", "matched", "unchecked", "matched"],
      source: ["matched", "mismatched", "unchecked", "unchecked", "matched", "unchecked"],
      coordinate: ["matched", "matched", "mismatched", "matched", "matched", "matched"],
      observations: ["matched", "matched", "matched", "mismatched", "matched", "matched"],
      digest: ["matched", "matched", "matched", "matched", "mismatched", "matched"],
      residual: ["matched", "matched", "matched", "matched", "matched", "mismatched"],
    };
    for (const condition of CONDITIONS) {
      assert.deepEqual(kinds(admitBroken([condition])), expectedKinds[condition], condition);
    }
  });

  it("reports all four independent conditions at once", () => {
    assert.deepEqual(kinds(admitBroken(["coordinate", "observations", "digest", "residual"])), [
      "matched",
      "matched",
      "mismatched",
      "mismatched",
      "mismatched",
      "mismatched",
    ]);
  });

  it("reports the digest condition without evaluating the source children when the source fails", () => {
    const mismatch = admitBroken(["source", "coordinate", "digest", "residual"]);
    assert.deepEqual(kinds(mismatch), ["matched", "mismatched", "unchecked", "unchecked", "mismatched", "unchecked"]);
  });

  it("reports both roots and leaves every dependent condition unchecked", () => {
    const mismatch = admitBroken(["decode", "source"]);
    assert.deepEqual(kinds(mismatch), [
      "mismatched",
      "mismatched",
      "unchecked",
      "unchecked",
      "unchecked",
      "unchecked",
    ]);
  });

  it("evaluates the source children when only the decode root fails", () => {
    const mismatch = admitBroken(["decode", "coordinate", "observations", "residual"]);
    assert.deepEqual(kinds(mismatch), [
      "mismatched",
      "matched",
      "mismatched",
      "mismatched",
      "unchecked",
      "mismatched",
    ]);
  });

  it("keeps the failed prerequisite as the evidence of an unchecked condition", () => {
    const mismatch = admitBroken(["decode", "source"]);
    const decode = mismatch.checks.decode;
    const source = mismatch.checks.source;
    assert.equal(decode.kind, "failed");
    assert.equal(source.kind, "failed");
    if (decode.kind !== "failed" || source.kind !== "failed") return;
    const digest = mismatch.statusAt("digest");
    assert.equal(digest.kind, "unchecked_by_decode");
    if (digest.kind === "unchecked_by_decode") assert.equal(digest.failure, decode.failure);
    for (const condition of ["coordinate", "observations", "residual"] as const) {
      const status = mismatch.statusAt(condition);
      assert.equal(status.kind, "unchecked_by_source");
      if (status.kind === "unchecked_by_source") assert.equal(status.failure, source.failure);
    }
  });

  it("does not compare a condition whose prerequisite failed", () => {
    let sameCoordinateCalls = 0;
    const comparison: Comparison<string, string, string, string, string> = {
      ...stringComparison,
      sameCoordinate: (left, right) => {
        sameCoordinateCalls += 1;
        return left === right;
      },
    };
    admit(table(), breakAll(["source"]), fixtureExpected(), "caller", comparison);
    assert.equal(sameCoordinateCalls, 0);
    admit(table(), fixtureCertificate(), fixtureExpected(), "caller", comparison);
    assert.equal(sameCoordinateCalls, 1);
  });

  it("does not run the rule for an unregistered revision", () => {
    calls = 0;
    admitBroken(["decode"]);
    assert.equal(calls, 0);
  });

  it("reports an unknown revision at decode when the versions agree", () => {
    const certificate = { ...fixtureCertificate(), ruleRevision: "rule@9" };
    const expected = { ...fixtureExpected(), ruleRevision: "rule@9" };
    const mismatch = rejected(admit(table(), certificate, expected, "caller", stringComparison));
    assert.equal(mismatch.checks.decode.kind, "failed");
    if (mismatch.checks.decode.kind !== "failed") return;
    assert.equal(mismatch.checks.decode.failure.expected, "rule in table");
    assert.equal(mismatch.checks.decode.failure.actual, "rule@9");
  });

  it("reports a version mismatch with the expected revision", () => {
    const mismatch = admitBroken(["decode"]);
    assert.equal(mismatch.checks.decode.kind, "failed");
    if (mismatch.checks.decode.kind !== "failed") return;
    assert.equal(mismatch.checks.decode.failure.expected, "rule@1");
    assert.equal(mismatch.checks.decode.failure.actual, "rule@2");
  });

  it("reports an evidence change at the digest condition alone", () => {
    const certificate = { ...fixtureCertificate(), evidence: "e6" };
    const mismatch = rejected(admit(table(), certificate, fixtureExpected(), "caller", stringComparison));
    assert.deepEqual(kinds(mismatch), ["matched", "matched", "matched", "matched", "mismatched", "matched"]);
  });

  it("reports the same revision with other rule semantics as different on every name", () => {
    const other: Rule<string, string, string, string, string> = (source, coordinate, observations, evidence) =>
      digestsFor(source, coordinate, observations, evidence, "other");
    const mismatch = rejected(
      admit(table([["rule@1", other]] as const), fixtureCertificate(), fixtureExpected(), "caller", stringComparison),
    );
    assert.equal(mismatch.checks.decode.kind, "established");
    if (mismatch.checks.decode.kind !== "established") return;
    assert.deepEqual(
      mismatch.checks.decode.children.entries().map(([name, result]) => [name, result.kind]),
      [["graph", "different"], ["metadata", "different"]],
    );
  });
});

describe("a mismatch carries the structure of the failure", () => {
  it("is a sealed value with the checks, the origin and the provenance", () => {
    const mismatch = admitBroken(["source"]);
    assert.ok(mismatch instanceof Mismatch);
    assert.equal(Object.isFrozen(mismatch), true);
    assert.equal(mismatch.checks.source.kind, "failed");
    if (mismatch.checks.source.kind !== "failed") return;
    const failure = mismatch.checks.source.failure;
    assert.deepEqual(Object.keys(failure).sort(), ["actual", "condition", "expected", "operation", "origin", "provenance"]);
    assert.equal(failure.condition, "source");
    assert.equal(failure.operation, "admit");
    assert.equal(failure.expected, "src@7");
    assert.equal(failure.actual, "src@8");
    assert.equal(mismatch.provenance, "caller");
    assert.equal(
      mismatch.toString(),
      "admit failed at source: rule rule@1, source src@8",
    );
  });

  it("cannot be built from checks that all match", () => {
    const matched = check(table(), fixtureCertificate(), fixtureExpected(), "caller", stringComparison);
    const forge = Mismatch as unknown as new (checks: unknown) => unknown;
    assert.throws(() => new forge(matched), TypeError);
  });

  it("lists the failed conditions in the message", () => {
    const mismatch = admitBroken(["coordinate", "residual"]);
    assert.equal(mismatch.toString(), "admit failed at coordinate, residual: rule rule@1, source src@7");
  });

  it("takes the origin from the certificate and keeps the caller provenance by identity", () => {
    const provenance = { caller: "run-42" };
    const certificate = { ...fixtureCertificate(), ruleRevision: "rule@2", source: { identity: "other", revision: "7" } };
    const mismatch = rejected(admit(table(), certificate, fixtureExpected(), provenance, stringComparison));
    assert.equal(mismatch.provenance, provenance);
    assert.deepEqual(mismatch.origin, {
      ruleRevision: "rule@2",
      sourceIdentity: "other",
      sourceRevision: "7",
    });
    for (const failure of [mismatch.checks.decode, mismatch.checks.source]) {
      assert.equal(failure.kind, "failed");
      if (failure.kind === "failed") {
        assert.equal(failure.failure.provenance, provenance);
        assert.deepEqual(failure.failure.origin, mismatch.origin);
      }
    }
  });
});

describe("admit uses the equalities that the caller passes", () => {
  it("calls the caller equality for the residual set and reports the set at residual", () => {
    let seen = 0;
    const comparison: Comparison<string, string, string, string, string> = {
      ...stringComparison,
      sameResidual: (left, right) => {
        seen += 1;
        return left === right;
      },
    };
    const certificate = { ...fixtureCertificate(), residuals: residualSet(["r2", "r3"]) };
    const mismatch = rejected(admit(table(), certificate, fixtureExpected(), "caller", comparison));
    assert.equal(mismatch.statusAt("residual").kind, "mismatched");
    assert.ok(seen >= 1);
  });

  it("preserves distinct values while comparing membership with the caller equality", () => {
    const comparison: Comparison<string, string, string, string, string> = {
      ...stringComparison,
      sameResidual: (left, right) => left.toLowerCase() === right.toLowerCase(),
    };
    const certificate = {
      ...fixtureCertificate(),
      residuals: residualSet(["r2", "R2", "r2"]),
    };
    const expected = {
      ...fixtureExpected(),
      residuals: residualSet(["R2"]),
    };
    const result = admit(table(), certificate, expected, "caller", comparison);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.value.certificate.residuals.values, ["r2", "R2"]);
  });
});

describe("the rule table is copied at construction", () => {
  it("keeps the rule of the revision and ignores later mutation of the caller array", () => {
    calls = 0;
    const entries: [string, Rule<string, string, string, string, string>][] = [["rule@1", rule]];
    const built = RuleTable.create(entries);
    assert.equal(built.ok, true);
    if (!built.ok) return;
    entries[0] = ["rule@1", (source, coordinate, observations, evidence) => digestsFor(source, coordinate, observations, evidence, "replaced")];
    entries.push(["rule@2", rule]);
    const result = admit(built.value, fixtureCertificate(), fixtureExpected(), "caller", stringComparison);
    assert.equal(result.ok, true);
    assert.equal(calls, 1);
    const later = admit(built.value, { ...fixtureCertificate(), ruleRevision: "rule@2" }, { ...fixtureExpected(), ruleRevision: "rule@2" }, "caller", stringComparison);
    const error = rejected(later);
    assert.equal(error.checks.decode.kind, "failed");
    if (error.checks.decode.kind === "failed") assert.equal(error.checks.decode.failure.expected, "rule in table");
  });
});

const ruleA: Rule<string, string, string, string, string> = (source, coordinate, observations, evidence) =>
  digestsFor(source, coordinate, observations, evidence, "rule-a");
const ruleB: Rule<string, string, string, string, string> = (source, coordinate, observations, evidence) =>
  digestsFor(source, coordinate, observations, evidence, "rule-b");

describe("the rule table rejects a duplicate revision at construction", () => {
  it("returns the first revision that appears a second time", () => {
    const built = RuleTable.create([
      ["rule@2", ruleB],
      ["rule@1", ruleA],
      ["rule@2", ruleB],
      ["rule@1", ruleA],
    ] as const);
    assert.equal(built.ok, false);
    if (built.ok) return;
    assert.equal(built.error.ruleRevision, "rule@2");
  });
});

describe("the selected rule does not depend on the order of the table", () => {
  const source = { identity: "src", revision: "7" };
  const digestsA = ruleA(source, "c1", "d3", "e5");
  const digestsB = ruleB(source, "c1", "d3", "e5");

  function certificateFor(revision: string, digests: ProjectionDigestsInput): Cert {
    return {
      ruleRevision: revision,
      source,
      coordinate: "c1",
      digests: projectionDigests(digests),
      residuals: residualSet(["r2"]),
      observations: "d3",
      evidence: "e5",
    };
  }

  function expectedFor(revision: string): Exp {
    return {
      ruleRevision: revision,
      source,
      coordinate: "c1",
      observations: "d3",
      residuals: residualSet(["r2"]),
    };
  }

  function buildTables() {
    const forward = RuleTable.create([
      ["rule@1", ruleA],
      ["rule@2", ruleB],
    ] as const);
    const backward = RuleTable.create([
      ["rule@2", ruleB],
      ["rule@1", ruleA],
    ] as const);
    assert.equal(forward.ok, true);
    assert.equal(backward.ok, true);
    if (!forward.ok || !backward.ok) throw new Error("both fixture tables are built");
    return [forward.value, backward.value] as const;
  }

  it("admits each version with its own recomputed digests in both table orders", () => {
    for (const tableValue of buildTables()) {
      const first = admit(tableValue, certificateFor("rule@1", digestsA), expectedFor("rule@1"), "caller", stringComparison);
      assert.equal(first.ok, true);
      if (first.ok) assert.deepEqual(first.value.recomputed.entries(), projectionDigests(digestsA).entries());

      const second = admit(tableValue, certificateFor("rule@2", digestsB), expectedFor("rule@2"), "caller", stringComparison);
      assert.equal(second.ok, true);
      if (second.ok) assert.deepEqual(second.value.recomputed.entries(), projectionDigests(digestsB).entries());
    }
  });

  it("mismatches the digest condition when a version carries the digests of another rule in both table orders", () => {
    for (const tableValue of buildTables()) {
      const crossed = admit(tableValue, certificateFor("rule@1", digestsB), expectedFor("rule@1"), "caller", stringComparison);
      const error = rejected(crossed);
      assert.equal(error.statusAt("digest").kind, "mismatched");
      assert.equal(error.statusAt("decode").kind, "matched");
    }
  });
});
