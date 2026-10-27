export type Equality<T> = (left: T, right: T) => boolean;

export type Comparison<S, Rev, C, Obs, R> = {
  readonly sameSource: Equality<S>;
  readonly sameRevision: Equality<Rev>;
  readonly sameCoordinate: Equality<C>;
  readonly sameObservations: Equality<Obs>;
  readonly sameResidual: Equality<R>;
  readonly identityText: (identity: S) => string;
  readonly revisionText: (revision: Rev) => string;
};
