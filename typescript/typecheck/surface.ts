import {
  Checked,
  RuleTable,
  admit,
  type Certificate,
  type Comparison,
  type Expected,
  type Mismatch,
  type ProjectionDigest,
  type Result,
  type Rule,
  residualSet,
} from "../src/index.ts";

type Identity = { readonly id: number };
type Coordinate = readonly [number, number];
type Evidence = Uint8Array;

type Cert = Certificate<Identity, bigint, Coordinate, boolean, symbol, Evidence>;
type Exp = Expected<Identity, bigint, Coordinate, boolean, symbol>;
type Table = RuleTable<Identity, bigint, Coordinate, boolean, Evidence>;

const rule: Rule<Identity, bigint, Coordinate, boolean, Evidence> = () => {
  const digests: ProjectionDigest[] = [];
  return digests;
};

const comparison: Comparison<Identity, bigint, Coordinate, boolean, symbol> = {
  sameSource: (left, right) => left.id === right.id,
  sameRevision: (left, right) => left === right,
  sameCoordinate: (left, right) => left[0] === right[0] && left[1] === right[1],
  sameObservations: (left, right) => left === right,
  sameResidual: (left, right) => left === right,
  identityText: (identity) => String(identity.id),
  revisionText: (revision) => revision.toString(),
};

const built = RuleTable.create([["rule@1", rule]] as const);
if (!built.ok) {
  throw new Error("fixture table has unique revisions");
}
const table: Table = built.value;

const duplicate = RuleTable.create([
  ["rule@1", rule],
  ["rule@1", rule],
] as const);
const duplicateRevision: string | undefined = duplicate.ok ? undefined : duplicate.error.ruleRevision;
void duplicateRevision;

const certificate: Cert = {
  ruleRevision: "rule@1",
  source: { identity: { id: 1 }, revision: 2n },
  coordinate: [0, 0],
  digests: [],
  residuals: residualSet([Symbol("residual")]),
  observations: false,
  evidence: new Uint8Array(),
};

const expected: Exp = {
  ruleRevision: "rule@1",
  source: { identity: { id: 1 }, revision: 2n },
  coordinate: [0, 0],
  observations: false,
  residuals: residualSet([]),
};

const outcome: Result<Checked<Identity, bigint, Coordinate, boolean, symbol, Evidence>, Mismatch<{ caller: string }>> =
  admit(table, certificate, expected, { caller: "fixture" }, comparison);
if (outcome.ok) {
  const digests: readonly ProjectionDigest[] = outcome.value.recomputed;
  void digests;
}

// @ts-expect-error
const forged = new Checked(table, certificate, []);
void forged;

// @ts-expect-error
const forgedTable = new RuleTable([]);
void forgedTable;

// @ts-expect-error
const factoryUse = Checked.create;
void factoryUse;

// @ts-expect-error
if (outcome.ok) outcome.value.certificate.digests.push({ projection: "x", digest: "y", scope: { kind: "cross_language", encoding: "z" } });

// @ts-expect-error
const unknownScope: ProjectionDigest["scope"] = { kind: "other", encoding: "z" };
void unknownScope;

// @ts-expect-error
const incomplete: Comparison<Identity, bigint, Coordinate, boolean, symbol> = { sameSource: comparison.sameSource };
void incomplete;

// @ts-expect-error
const wrongEquality: Comparison<Identity, bigint, Coordinate, boolean, symbol> = { ...comparison, sameSource: (left: string, right: string) => left === right };
void wrongEquality;

// @ts-expect-error
void admit(table, certificate, expected, "caller");
