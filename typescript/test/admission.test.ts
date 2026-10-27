import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  Checked,
  RuleTable,
  admit,
  type Certificate,
  type Mismatch,
  type Result,
  type Comparison,
  type Expected,
  type ProjectionDigest,
  type Rule,
  type Stage,
  residualSet,
} from "../src/index.ts";
import { stringComparison } from "./support.ts";

type Cert = Certificate<string, string, string, string, string, string>;
type Exp = Expected<string, string, string, string, string>;

const STAGES: readonly Stage[] = ["decode", "source", "coordinate", "observations", "digest", "residual"];

let calls = 0;

function digestsFor(
  source: { identity: string; revision: string },
  coordinate: string,
  observations: string,
  evidence: string,
  salt = "default",
): ProjectionDigest[] {
  return ["graph", "metadata"].map((projection) => ({
    projection,
    digest: `${salt}|${projection}|${source.identity}@${source.revision}|${coordinate}|${observations}|${evidence}`,
    scope: { kind: "cross_language", encoding: "fnv1a-64" },
  }));
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

function fixtureCertificate(): Cert {
  return {
    ruleRevision: "rule@1",
    source: { identity: "src", revision: "7" },
    coordinate: "c1",
    digests: digestsFor({ identity: "src", revision: "7" }, "c1", "d3", "e5"),
    residuals: residualSet(["r2"]),
    observations: "d3",
    evidence: "e5",
  };
}

function fixtureExpected(): Exp {
  return {
    ruleRevision: "rule@1",
    source: { identity: "src", revision: "7" },
    coordinate: "c1",
    observations: "d3",
    residuals: residualSet(["r2"]),
  };
}

function breakStage(certificate: Cert, stage: Stage): Cert {
  switch (stage) {
    case "decode":
      return { ...certificate, ruleRevision: "rule@2" };
    case "source":
      return { ...certificate, source: { identity: "src", revision: "8" } };
    case "coordinate":
      return { ...certificate, coordinate: "c9" };
    case "observations":
      return { ...certificate, observations: "d9" };
    case "digest":
      return { ...certificate, digests: digestsFor({ identity: "src", revision: "7" }, "c1", "d3", "e5", "other") };
    case "residual":
      return { ...certificate, residuals: residualSet(["r9"]) };
  }
}

function rejected(result: Result<unknown, Mismatch<unknown>>): Mismatch<unknown> {
  assert.equal(result.ok, false, "the certificate is rejected");
  if (result.ok) throw new Error("unreachable");
  return result.error;
}

describe("admit accepts a consistent certificate", () => {
  it("returns a checked value with the certificate and the recomputed digests", () => {
    const result = admit(table(), fixtureCertificate(), fixtureExpected(), "caller", stringComparison);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.ok(result.value instanceof Checked);
    assert.deepEqual(result.value.certificate, fixtureCertificate());
    assert.deepEqual(result.value.source, { identity: "src", revision: "7" });
    assert.deepEqual(result.value.recomputed, digestsFor({ identity: "src", revision: "7" }, "c1", "d3", "e5"));
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

describe("admit reports the first failing stage", () => {
  it("reports each stage alone at that stage", () => {
    for (const stage of STAGES) {
      const error = rejected(admit(table(), breakStage(fixtureCertificate(), stage), fixtureExpected(), "caller", stringComparison));
      assert.equal(error.stage, stage);
    }
  });

  it("reports each stage at the earliest broken stage when all later stages break too", () => {
    for (const [index, stage] of STAGES.entries()) {
      let certificate = fixtureCertificate();
      for (const later of STAGES.slice(index)) {
        certificate = breakStage(certificate, later);
      }
      const error = rejected(admit(table(), certificate, fixtureExpected(), "caller", stringComparison));
      assert.equal(error.stage, stage);
    }
  });

  it("reports a version mismatch before an unknown revision", () => {
    const certificate = { ...fixtureCertificate(), ruleRevision: "rule@2" };
    const error = rejected(admit(table(), certificate, fixtureExpected(), "caller", stringComparison));
    assert.equal(error.stage, "decode");
    assert.equal(error.expected, "rule@1");
    assert.equal(error.actual, "rule@2");
  });

  it("reports an unknown revision at decode when the versions agree", () => {
    const certificate = { ...fixtureCertificate(), ruleRevision: "rule@9" };
    const expected = { ...fixtureExpected(), ruleRevision: "rule@9" };
    const error = rejected(admit(table(), certificate, expected, "caller", stringComparison));
    assert.equal(error.stage, "decode");
    assert.equal(error.expected, "rule in table");
    assert.equal(error.actual, "rule@9");
  });

  it("reports an evidence change alone at digest", () => {
    const certificate = { ...fixtureCertificate(), evidence: "e6" };
    const error = rejected(admit(table(), certificate, fixtureExpected(), "caller", stringComparison));
    assert.equal(error.stage, "digest");
  });

  it("reports the same revision with other rule semantics at digest", () => {
    const other: Rule<string, string, string, string, string> = (source, coordinate, observations, evidence) =>
      digestsFor(source, coordinate, observations, evidence, "other");
    const error = rejected(
      admit(table([["rule@1", other]] as const), fixtureCertificate(), fixtureExpected(), "caller", stringComparison),
    );
    assert.equal(error.stage, "digest");
    assert.match(error.expected, /other\|graph/);
  });
});

describe("a mismatch carries every field of the failure", () => {
  it("has the operation, stage, expected, actual, origin, provenance and contributing fields", () => {
    const certificate = { ...fixtureCertificate(), source: { identity: "other", revision: "11" } };
    const error = rejected(admit(table(), certificate, fixtureExpected(), "caller", stringComparison));
    assert.deepEqual(Object.keys(error).sort(), [
      "actual",
      "contributing",
      "expected",
      "operation",
      "origin",
      "provenance",
      "stage",
    ]);
    assert.equal(error.operation, "admit");
    assert.equal(error.stage, "source");
    assert.equal(error.expected, "src@7");
    assert.equal(error.actual, "other@11");
    assert.equal(error.provenance, "caller");
    assert.deepEqual(error.contributing, []);
  });

  it("takes the origin from the certificate and keeps the caller provenance by identity", () => {
    const provenance = { caller: "run-42" };
    const certificate = { ...fixtureCertificate(), ruleRevision: "rule@2", source: { identity: "other", revision: "7" } };
    const error = rejected(admit(table(), certificate, fixtureExpected(), provenance, stringComparison));
    assert.equal(error.stage, "decode");
    assert.equal(error.provenance, provenance);
    assert.deepEqual(error.origin, {
      ruleRevision: "rule@2",
      sourceIdentity: "other",
      sourceRevision: "7",
    });
  });

  it("builds the source origin from the certificate", () => {
    const certificate = { ...fixtureCertificate(), source: { identity: "other", revision: "11" } };
    const error = rejected(admit(table(), certificate, fixtureExpected(), "caller", stringComparison));
    assert.deepEqual(error.origin, { ruleRevision: "rule@1", sourceIdentity: "other", sourceRevision: "11" });
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
    const error = rejected(admit(table(), certificate, fixtureExpected(), "caller", comparison));
    assert.equal(error.stage, "residual");
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
    assert.equal(later.ok, false);
    if (later.ok) return;
    assert.equal(later.error.expected, "rule in table");
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

  function certificateFor(revision: string, digests: readonly ProjectionDigest[]): Cert {
    return {
      ruleRevision: revision,
      source,
      coordinate: "c1",
      digests,
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
      if (first.ok) assert.deepEqual(first.value.recomputed, digestsA);

      const second = admit(tableValue, certificateFor("rule@2", digestsB), expectedFor("rule@2"), "caller", stringComparison);
      assert.equal(second.ok, true);
      if (second.ok) assert.deepEqual(second.value.recomputed, digestsB);
    }
  });

  it("fails at digest when a version carries the digests of another rule in both table orders", () => {
    for (const tableValue of buildTables()) {
      const crossed = admit(tableValue, certificateFor("rule@1", digestsB), expectedFor("rule@1"), "caller", stringComparison);
      assert.equal(crossed.ok, false);
      if (crossed.ok) continue;
      assert.equal(crossed.error.stage, "digest");
    }
  });
});
