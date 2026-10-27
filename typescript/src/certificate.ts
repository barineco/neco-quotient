import { type ProjectionDigest, freezeProjectionDigests } from "./digest.ts";
import type { Equality } from "./comparison.ts";

export class ResidualSet<R> {
  readonly values: readonly R[];

  constructor(values: readonly R[]) {
    const unique: R[] = [];
    for (const value of values) {
      if (!unique.some((item) => Object.is(item, value))) unique.push(value);
    }
    this.values = Object.freeze(unique);
    Object.freeze(this);
  }

  sameElements(other: ResidualSet<R>, same: Equality<R>): boolean {
    return this.values.every((value) => other.values.some((item) => same(value, item)))
      && other.values.every((value) => this.values.some((item) => same(value, item)));
  }
}

export function residualSet<R>(values: readonly R[]): ResidualSet<R> {
  return new ResidualSet(values);
}

export type SourceRef<S, Rev> = {
  readonly identity: S;
  readonly revision: Rev;
};

export type Certificate<S, Rev, C, Obs, R, E> = {
  readonly ruleRevision: string;
  readonly source: SourceRef<S, Rev>;
  readonly coordinate: C;
  readonly digests: readonly ProjectionDigest[];
  readonly residuals: ResidualSet<R>;
  readonly observations: Obs;
  readonly evidence: E;
};

export type Expected<S, Rev, C, Obs, R> = {
  readonly ruleRevision: string;
  readonly source: SourceRef<S, Rev>;
  readonly coordinate: C;
  readonly observations: Obs;
  readonly residuals: ResidualSet<R>;
};

export function freezeCertificate<S, Rev, C, Obs, R, E>(
  certificate: Certificate<S, Rev, C, Obs, R, E>,
): Certificate<S, Rev, C, Obs, R, E> {
  return Object.freeze({
    ruleRevision: certificate.ruleRevision,
    source: Object.freeze({
      identity: certificate.source.identity,
      revision: certificate.source.revision,
    }),
    coordinate: certificate.coordinate,
    digests: freezeProjectionDigests(certificate.digests),
    residuals: residualSet(certificate.residuals.values),
    observations: certificate.observations,
    evidence: certificate.evidence,
  });
}
