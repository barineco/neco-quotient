import type { Certificate, Expected, SourceRef } from "./certificate.ts";
import { freezeCertificate, freezeExpected } from "./certificate.ts";
import type {
  AdmissionChecks,
  CheckResult,
  Condition,
  DigestChecks,
  Prerequisite,
  ProjectionResult,
  SourceChecks,
} from "./checks.ts";
import { newAdmissionChecks } from "./checks.ts";
import type { Comparison } from "./comparison.ts";
import { describeList } from "./diagnostic.ts";
import type { ProjectionDigests } from "./digest.ts";
import { NameMap, projectionDigests, sameProjectionDigest } from "./digest.ts";
import type { ConditionFailure, Mismatch, Origin } from "./failure.ts";
import { newMismatch } from "./failure.ts";
import type { Result } from "./result.ts";
import type { Rule, RuleTable } from "./rule.ts";

const OPERATION = "admit";
const TABLE_EXPECTATION = "rule in table";

type Seal = <S, Rev, C, Obs, R, E>(
  table: RuleTable<S, Rev, C, Obs, E>,
  certificate: Certificate<S, Rev, C, Obs, R, E>,
  expected: Expected<S, Rev, C, Obs, R>,
  recomputed: ProjectionDigests,
) => Checked<S, Rev, C, Obs, R, E>;

let seal!: Seal;

type CheckedState<S, Rev, C, Obs, R, E> = {
  readonly table: RuleTable<S, Rev, C, Obs, E>;
  readonly certificate: Certificate<S, Rev, C, Obs, R, E>;
  readonly expected: Expected<S, Rev, C, Obs, R>;
  readonly recomputed: ProjectionDigests;
};

export class Checked<S, Rev, C, Obs, R, E> {
  readonly #state: CheckedState<S, Rev, C, Obs, R, E>;

  private constructor(state: CheckedState<S, Rev, C, Obs, R, E>) {
    this.#state = Object.freeze(state);
  }

  static {
    seal = (table, certificate, expected, recomputed) =>
      new Checked({ table, certificate, expected, recomputed });
  }

  get certificate(): Certificate<S, Rev, C, Obs, R, E> {
    return this.#state.certificate;
  }

  get expected(): Expected<S, Rev, C, Obs, R> {
    return this.#state.expected;
  }

  get source(): SourceRef<S, Rev> {
    return this.#state.certificate.source;
  }

  get recomputed(): ProjectionDigests {
    return this.#state.recomputed;
  }
}

type Evaluation<P> = {
  readonly checks: AdmissionChecks<P>;
  readonly recomputed: ProjectionDigests | undefined;
};

export function admit<S, Rev, C, Obs, R, E, P>(
  table: RuleTable<S, Rev, C, Obs, E>,
  certificate: Certificate<S, Rev, C, Obs, R, E>,
  expected: Expected<S, Rev, C, Obs, R>,
  provenance: P,
  comparison: Comparison<S, Rev, C, Obs, R>,
): Result<Checked<S, Rev, C, Obs, R, E>, Mismatch<P>> {
  const snapshot = freezeCertificate(certificate);
  const expectedSnapshot = freezeExpected(expected);
  const { checks, recomputed } = evaluate(table, snapshot, expectedSnapshot, provenance, comparison);
  if (recomputed !== undefined && checks.allMatched()) {
    return { ok: true, value: seal(table, snapshot, expectedSnapshot, recomputed) };
  }
  return { ok: false, error: newMismatch(checks) };
}

export function check<S, Rev, C, Obs, R, E, P>(
  table: RuleTable<S, Rev, C, Obs, E>,
  certificate: Certificate<S, Rev, C, Obs, R, E>,
  expected: Expected<S, Rev, C, Obs, R>,
  provenance: P,
  comparison: Comparison<S, Rev, C, Obs, R>,
): AdmissionChecks<P> {
  return evaluate(
    table,
    freezeCertificate(certificate),
    freezeExpected(expected),
    provenance,
    comparison,
  ).checks;
}

function evaluate<S, Rev, C, Obs, R, E, P>(
  table: RuleTable<S, Rev, C, Obs, E>,
  certificate: Certificate<S, Rev, C, Obs, R, E>,
  expected: Expected<S, Rev, C, Obs, R>,
  provenance: P,
  comparison: Comparison<S, Rev, C, Obs, R>,
): Evaluation<P> {
  const origin: Origin = Object.freeze({
    ruleRevision: certificate.ruleRevision,
    sourceIdentity: comparison.identityText(certificate.source.identity),
    sourceRevision: comparison.revisionText(certificate.source.revision),
  });
  const failure = <K extends Condition>(
    condition: K,
    expectedText: string,
    actualText: string,
  ): ConditionFailure<K, P> =>
    Object.freeze({
      condition,
      operation: OPERATION,
      expected: expectedText,
      actual: actualText,
      origin,
      provenance,
    });
  const selected = selectRule(table, certificate, expected, failure);
  let decode: Prerequisite<ConditionFailure<"decode", P>, DigestChecks>;
  let recomputed: ProjectionDigests | undefined;
  if (typeof selected !== "function") {
    decode = { kind: "failed", failure: selected };
    recomputed = undefined;
  } else {
    recomputed = projectionDigests(
      selected(certificate.source, certificate.coordinate, certificate.observations, certificate.evidence),
    );
    decode = { kind: "established", children: compareDigests(recomputed, certificate.digests) };
  }
  const source = sourceBranch(certificate, expected, comparison, failure);
  return {
    checks: newAdmissionChecks({ origin, provenance, decode, source }),
    recomputed,
  };
}

function selectRule<S, Rev, C, Obs, R, E, P>(
  table: RuleTable<S, Rev, C, Obs, E>,
  certificate: Certificate<S, Rev, C, Obs, R, E>,
  expected: Expected<S, Rev, C, Obs, R>,
  failure: (condition: "decode", expectedText: string, actualText: string) => ConditionFailure<"decode", P>,
): Rule<S, Rev, C, Obs, E> | ConditionFailure<"decode", P> {
  if (certificate.ruleRevision !== expected.ruleRevision) {
    return failure("decode", expected.ruleRevision, certificate.ruleRevision);
  }
  return table.lookup(certificate.ruleRevision) ?? failure("decode", TABLE_EXPECTATION, certificate.ruleRevision);
}

function compareDigests(recomputed: ProjectionDigests, certificate: ProjectionDigests): DigestChecks {
  const names = new Set<string>([...recomputed.names(), ...certificate.names()]);
  const results = new Map<string, ProjectionResult>();
  for (const name of names) {
    const expected = recomputed.get(name);
    const actual = certificate.get(name);
    if (expected !== undefined && actual !== undefined) {
      results.set(
        name,
        sameProjectionDigest(expected, actual)
          ? Object.freeze({ kind: "matched", value: expected })
          : Object.freeze({ kind: "different", expected, actual }),
      );
    } else if (expected !== undefined) {
      results.set(name, Object.freeze({ kind: "recomputed_only", expected }));
    } else if (actual !== undefined) {
      results.set(name, Object.freeze({ kind: "certificate_only", actual }));
    }
  }
  return NameMap.copyOf(results, (result) => result);
}

function sourceBranch<S, Rev, C, Obs, R, E, P>(
  certificate: Certificate<S, Rev, C, Obs, R, E>,
  expected: Expected<S, Rev, C, Obs, R>,
  comparison: Comparison<S, Rev, C, Obs, R>,
  failure: <K extends Condition>(condition: K, expectedText: string, actualText: string) => ConditionFailure<K, P>,
): Prerequisite<ConditionFailure<"source", P>, SourceChecks<P>> {
  const sourceText = (source: SourceRef<S, Rev>): string =>
    `${comparison.identityText(source.identity)}@${comparison.revisionText(source.revision)}`;
  if (
    !comparison.sameSource(certificate.source.identity, expected.source.identity) ||
    !comparison.sameRevision(certificate.source.revision, expected.source.revision)
  ) {
    return {
      kind: "failed",
      failure: failure("source", sourceText(expected.source), sourceText(certificate.source)),
    };
  }
  const children: SourceChecks<P> = Object.freeze({
    coordinate: conditionResult(comparison.sameCoordinate(certificate.coordinate, expected.coordinate), () =>
      failure("coordinate", String(expected.coordinate), String(certificate.coordinate)),
    ),
    observations: conditionResult(
      comparison.sameObservations(certificate.observations, expected.observations),
      () => failure("observations", String(expected.observations), String(certificate.observations)),
    ),
    residual: conditionResult(
      certificate.residuals.sameElements(expected.residuals, comparison.sameResidual),
      () => failure("residual", describeList(expected.residuals.values), describeList(certificate.residuals.values)),
    ),
  });
  return { kind: "established", children };
}

function conditionResult<F>(holds: boolean, failure: () => F): CheckResult<F> {
  return holds ? MATCHED : Object.freeze({ kind: "mismatched", failure: failure() });
}

const MATCHED: CheckResult<never> = Object.freeze({ kind: "matched" });
