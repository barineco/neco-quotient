export type Stage = "decode" | "source" | "coordinate" | "observations" | "digest" | "residual";

export type Origin = {
  readonly ruleRevision: string;
  readonly sourceIdentity: string;
  readonly sourceRevision: string;
};

export type Mismatch<P> = {
  readonly operation: "admit";
  readonly stage: Stage;
  readonly expected: string;
  readonly actual: string;
  readonly origin: Origin;
  readonly provenance: P;
  readonly contributing: readonly Mismatch<P>[];
};
