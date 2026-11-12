import type { NameMap, ProjectionDigest } from "./digest.ts";
import type { ConditionFailure, Origin } from "./failure.ts";

export type Condition =
  | "decode"
  | "source"
  | "coordinate"
  | "observations"
  | "digest"
  | "residual";

export const CONDITIONS: readonly Condition[] = Object.freeze([
  "decode",
  "source",
  "coordinate",
  "observations",
  "digest",
  "residual",
]);

export function conditionPrerequisite(condition: Condition): Condition | undefined {
  switch (condition) {
    case "decode":
    case "source":
      return undefined;
    case "digest":
      return "decode";
    case "coordinate":
    case "observations":
    case "residual":
      return "source";
  }
}

export type Prerequisite<F, C> =
  | { readonly kind: "failed"; readonly failure: F }
  | { readonly kind: "established"; readonly children: C };

export type CheckResult<F> =
  | { readonly kind: "matched" }
  | { readonly kind: "mismatched"; readonly failure: F };

export type ProjectionResult =
  | { readonly kind: "matched"; readonly value: ProjectionDigest }
  | { readonly kind: "certificate_only"; readonly actual: ProjectionDigest }
  | { readonly kind: "recomputed_only"; readonly expected: ProjectionDigest }
  | {
      readonly kind: "different";
      readonly expected: ProjectionDigest;
      readonly actual: ProjectionDigest;
    };

export type DigestChecks = NameMap<ProjectionResult>;

export function isProjectionMatched(result: ProjectionResult): boolean {
  return result.kind === "matched";
}

export function isCheckMatched(result: CheckResult<unknown>): boolean {
  return result.kind === "matched";
}

export type SourceChecks<P> = {
  readonly coordinate: CheckResult<ConditionFailure<"coordinate", P>>;
  readonly observations: CheckResult<ConditionFailure<"observations", P>>;
  readonly residual: CheckResult<ConditionFailure<"residual", P>>;
};

export type Status<P> =
  | { readonly kind: "matched" }
  | { readonly kind: "mismatched" }
  | { readonly kind: "unchecked_by_decode"; readonly failure: ConditionFailure<"decode", P> }
  | { readonly kind: "unchecked_by_source"; readonly failure: ConditionFailure<"source", P> };

const MATCHED: Status<never> = Object.freeze({ kind: "matched" });
const MISMATCHED: Status<never> = Object.freeze({ kind: "mismatched" });

function statusOf(matched: boolean): Status<never> {
  return matched ? MATCHED : MISMATCHED;
}

function digestChecksMatched(checks: DigestChecks): boolean {
  return checks.values().every(isProjectionMatched);
}

function sourceChecksMatched<P>(checks: SourceChecks<P>): boolean {
  return (
    isCheckMatched(checks.coordinate) &&
    isCheckMatched(checks.observations) &&
    isCheckMatched(checks.residual)
  );
}

type AdmissionChecksParts<P> = {
  readonly origin: Origin;
  readonly provenance: P;
  readonly decode: Prerequisite<ConditionFailure<"decode", P>, DigestChecks>;
  readonly source: Prerequisite<ConditionFailure<"source", P>, SourceChecks<P>>;
};

type SealChecks = <P>(parts: AdmissionChecksParts<P>) => AdmissionChecks<P>;

let sealChecks!: SealChecks;

export class AdmissionChecks<P> {
  readonly origin: Origin;
  readonly provenance: P;
  readonly decode: Prerequisite<ConditionFailure<"decode", P>, DigestChecks>;
  readonly source: Prerequisite<ConditionFailure<"source", P>, SourceChecks<P>>;

  private constructor(parts: AdmissionChecksParts<P>) {
    this.origin = parts.origin;
    this.provenance = parts.provenance;
    this.decode = parts.decode;
    this.source = parts.source;
    Object.freeze(this);
  }

  static {
    sealChecks = (parts) => new AdmissionChecks(parts);
  }

  allMatched(): boolean {
    const decode = this.decode.kind === "established" && digestChecksMatched(this.decode.children);
    const source = this.source.kind === "established" && sourceChecksMatched(this.source.children);
    return decode && source;
  }

  statusAt(condition: Condition): Status<P> {
    switch (condition) {
      case "decode":
        return statusOf(this.decode.kind === "established");
      case "source":
        return statusOf(this.source.kind === "established");
      case "digest":
        return this.decode.kind === "failed"
          ? Object.freeze({ kind: "unchecked_by_decode", failure: this.decode.failure })
          : statusOf(digestChecksMatched(this.decode.children));
      case "coordinate":
        return this.sourceChild((children) => isCheckMatched(children.coordinate));
      case "observations":
        return this.sourceChild((children) => isCheckMatched(children.observations));
      case "residual":
        return this.sourceChild((children) => isCheckMatched(children.residual));
    }
  }

  private sourceChild(matched: (children: SourceChecks<P>) => boolean): Status<P> {
    return this.source.kind === "failed"
      ? Object.freeze({ kind: "unchecked_by_source", failure: this.source.failure })
      : statusOf(matched(this.source.children));
  }
}

export function newAdmissionChecks<P>(parts: AdmissionChecksParts<P>): AdmissionChecks<P> {
  return sealChecks(parts);
}
