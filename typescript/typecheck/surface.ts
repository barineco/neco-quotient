import {
  AdmissionChecks,
  Checked,
  Mismatch,
  NameMap,
  RuleTable,
  admit,
  projectionDigests,
  residual,
  resolved,
  stopped,
  type Certificate,
  type Comparison,
  type Condition,
  type ConditionFailure,
  type Expected,
  type ProjectionDigest,
  type ProjectionDigests,
  type RefinementOutcome,
  type Result,
  type Rule,
  type Status,
  residualSet,
} from "../src/index.ts";

type Identity = { readonly id: number };
type Coordinate = readonly [number, number];
type Evidence = Uint8Array;

type Cert = Certificate<Identity, bigint, Coordinate, boolean, symbol, Evidence>;
type Exp = Expected<Identity, bigint, Coordinate, boolean, symbol>;
type Table = RuleTable<Identity, bigint, Coordinate, boolean, Evidence>;

const rule: Rule<Identity, bigint, Coordinate, boolean, Evidence> = () => {
  const digests = new Map<string, ProjectionDigest>();
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
  digests: projectionDigests(new Map()),
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
  const digests: ProjectionDigests = outcome.value.recomputed;
  const first: ProjectionDigest | undefined = digests.get("graph");
  void first;
} else {
  const checks: AdmissionChecks<{ caller: string }> = outcome.error.checks;
  const status: Status<{ caller: string }> = outcome.error.statusAt("digest");
  const condition: Condition = "coordinate";
  void checks;
  void status;
  void condition;
  if (checks.decode.kind === "failed") {
    const failure: ConditionFailure<"decode", { caller: string }> = checks.decode.failure;
    void failure;
    // @ts-expect-error
    const wrongCondition: ConditionFailure<"source", { caller: string }> = checks.decode.failure;
    void wrongCondition;
  }
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
const forgedMismatch = new Mismatch(new Map());
void forgedMismatch;

// @ts-expect-error
const forgedChecks = new AdmissionChecks({});
void forgedChecks;

// @ts-expect-error
const forgedNameMap = new NameMap(new Map());
void forgedNameMap;

const digestMap = projectionDigests(new Map());

// @ts-expect-error
digestMap.set("graph", { digest: "y", scope: { kind: "cross_language", encoding: "z" } });

// @ts-expect-error
digestMap.delete("graph");

// @ts-expect-error
digestMap.clear();

// @ts-expect-error
const projectionName: string = digestMap.get("graph")?.projection;
void projectionName;

// @ts-expect-error
const bareArray: Certificate<Identity, bigint, Coordinate, boolean, symbol, Evidence> = { ...certificate, digests: [] };
void bareArray;

// @ts-expect-error
const unknownCondition: Condition = "stage";
void unknownCondition;

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

const determined: RefinementOutcome<Identity, symbol, string> = resolved({ id: 1 });
const remaining: RefinementOutcome<Identity, symbol, string> = residual({ id: 1 }, [Symbol("residual")]);
const halted: RefinementOutcome<Identity, symbol, string> = stopped({ id: 1 }, [], "budget");
void determined;
void remaining;
void halted;

// @ts-expect-error
const stoppedWithoutCause: RefinementOutcome<Identity, symbol, string> = { kind: "stopped", value: { id: 1 }, residuals: residualSet([]) };
void stoppedWithoutCause;

// @ts-expect-error
const wrongCause: RefinementOutcome<Identity, symbol, string> = stopped({ id: 1 }, [], 1);
void wrongCause;
