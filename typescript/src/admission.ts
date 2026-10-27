import type { Certificate, Expected, SourceRef } from "./certificate.ts";
import { freezeCertificate } from "./certificate.ts";
import type { Comparison } from "./comparison.ts";
import { describeDigests, describeList } from "./diagnostic.ts";
import {
  type ProjectionDigest,
  freezeProjectionDigests,
  sameProjectionDigests,
} from "./digest.ts";
import type { Mismatch, Stage } from "./failure.ts";
import type { Result } from "./result.ts";
import type { RuleTable } from "./rule.ts";

const OPERATION = "admit";
const TABLE_EXPECTATION = "rule in table";

type Seal = <S, Rev, C, Obs, R, E>(
  table: RuleTable<S, Rev, C, Obs, E>,
  certificate: Certificate<S, Rev, C, Obs, R, E>,
  recomputed: readonly ProjectionDigest[],
) => Checked<S, Rev, C, Obs, R, E>;

let seal!: Seal;

type CheckedState<S, Rev, C, Obs, R, E> = {
  readonly table: RuleTable<S, Rev, C, Obs, E>;
  readonly certificate: Certificate<S, Rev, C, Obs, R, E>;
  readonly recomputed: readonly ProjectionDigest[];
};

export class Checked<S, Rev, C, Obs, R, E> {
  readonly #state: CheckedState<S, Rev, C, Obs, R, E>;

  private constructor(
    table: RuleTable<S, Rev, C, Obs, E>,
    certificate: Certificate<S, Rev, C, Obs, R, E>,
    recomputed: readonly ProjectionDigest[],
  ) {
    this.#state = Object.freeze({ table, certificate, recomputed });
  }

  static {
    seal = (table, certificate, recomputed) => new Checked(table, certificate, recomputed);
  }

  get certificate(): Certificate<S, Rev, C, Obs, R, E> {
    return this.#state.certificate;
  }

  get source(): SourceRef<S, Rev> {
    return this.#state.certificate.source;
  }

  get recomputed(): readonly ProjectionDigest[] {
    return this.#state.recomputed;
  }
}

export function admit<S, Rev, C, Obs, R, E, P>(
  table: RuleTable<S, Rev, C, Obs, E>,
  certificate: Certificate<S, Rev, C, Obs, R, E>,
  expected: Expected<S, Rev, C, Obs, R>,
  provenance: P,
  comparison: Comparison<S, Rev, C, Obs, R>,
): Result<Checked<S, Rev, C, Obs, R, E>, Mismatch<P>> {
  const reject = (
    stage: Stage,
    expectedText: string,
    actualText: string,
  ): { readonly ok: false; readonly error: Mismatch<P> } => ({
    ok: false,
    error: {
      operation: OPERATION,
      stage,
      expected: expectedText,
      actual: actualText,
      origin: {
        ruleRevision: certificate.ruleRevision,
        sourceIdentity: comparison.identityText(certificate.source.identity),
        sourceRevision: comparison.revisionText(certificate.source.revision),
      },
      provenance,
      contributing: [],
    },
  });
  const sourceText = (source: SourceRef<S, Rev>): string =>
    `${comparison.identityText(source.identity)}@${comparison.revisionText(source.revision)}`;

  if (certificate.ruleRevision !== expected.ruleRevision) {
    return reject("decode", expected.ruleRevision, certificate.ruleRevision);
  }
  const rule = table.lookup(certificate.ruleRevision);
  if (rule === undefined) {
    return reject("decode", TABLE_EXPECTATION, certificate.ruleRevision);
  }
  if (
    !comparison.sameSource(certificate.source.identity, expected.source.identity) ||
    !comparison.sameRevision(certificate.source.revision, expected.source.revision)
  ) {
    return reject("source", sourceText(expected.source), sourceText(certificate.source));
  }
  if (!comparison.sameCoordinate(certificate.coordinate, expected.coordinate)) {
    return reject("coordinate", String(expected.coordinate), String(certificate.coordinate));
  }
  if (!comparison.sameObservations(certificate.observations, expected.observations)) {
    return reject("observations", String(expected.observations), String(certificate.observations));
  }
  const recomputed = freezeProjectionDigests(
    rule(certificate.source, certificate.coordinate, certificate.observations, certificate.evidence),
  );
  if (!sameProjectionDigests(certificate.digests, recomputed)) {
    return reject("digest", describeDigests(recomputed), describeDigests(certificate.digests));
  }
  if (!certificate.residuals.sameElements(expected.residuals, comparison.sameResidual)) {
    return reject("residual", describeList(expected.residuals.values), describeList(certificate.residuals.values));
  }
  return {
    ok: true,
    value: seal(table, freezeCertificate(certificate), recomputed),
  };
}
