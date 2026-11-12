import { type ResidualSet, residualSet } from "./certificate.ts";
import type { Equality } from "./comparison.ts";

export type RefinementOutcome<V, R, S> =
  | { readonly kind: "resolved"; readonly value: V }
  | { readonly kind: "residual"; readonly value: V; readonly residuals: ResidualSet<R> }
  | {
      readonly kind: "stopped";
      readonly value: V;
      readonly residuals: ResidualSet<R>;
      readonly cause: S;
    };

export type OutcomeComparison<V, R, S> = {
  readonly sameValue: Equality<V>;
  readonly sameResidual: Equality<R>;
  readonly sameCause: Equality<S>;
};

export function resolved<V, R, S>(value: V): RefinementOutcome<V, R, S> {
  return Object.freeze({ kind: "resolved", value });
}

export function residual<V, R, S>(
  value: V,
  residuals: readonly R[],
): RefinementOutcome<V, R, S> {
  return Object.freeze({ kind: "residual", value, residuals: residualSet(residuals) });
}

export function stopped<V, R, S>(
  value: V,
  residuals: readonly R[],
  cause: S,
): RefinementOutcome<V, R, S> {
  return Object.freeze({ kind: "stopped", value, residuals: residualSet(residuals), cause });
}

export function sameOutcome<V, R, S>(
  left: RefinementOutcome<V, R, S>,
  right: RefinementOutcome<V, R, S>,
  comparison: OutcomeComparison<V, R, S>,
): boolean {
  if (left.kind === "resolved") {
    return right.kind === "resolved" && comparison.sameValue(left.value, right.value);
  }
  if (left.kind === "residual") {
    return right.kind === "residual"
      && comparison.sameValue(left.value, right.value)
      && left.residuals.sameElements(right.residuals, comparison.sameResidual);
  }
  return right.kind === "stopped"
    && comparison.sameValue(left.value, right.value)
    && left.residuals.sameElements(right.residuals, comparison.sameResidual)
    && comparison.sameCause(left.cause, right.cause);
}
