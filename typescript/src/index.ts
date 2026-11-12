export type { Certificate, Expected, ResidualSet, SourceRef } from "./certificate.ts";
export { residualSet } from "./certificate.ts";
export type {
  CheckResult,
  Condition,
  DigestChecks,
  Prerequisite,
  ProjectionResult,
  SourceChecks,
  Status,
} from "./checks.ts";
export { AdmissionChecks, CONDITIONS, conditionPrerequisite } from "./checks.ts";
export type { Comparison, Equality } from "./comparison.ts";
export type {
  DigestScope,
  NameMapInput,
  ProjectionDigest,
  ProjectionDigests,
  ProjectionDigestsInput,
} from "./digest.ts";
export { NameMap, projectionDigests } from "./digest.ts";
export type { OutcomeComparison, RefinementOutcome } from "./refinement.ts";
export { residual, resolved, sameOutcome, stopped } from "./refinement.ts";
export type { ConditionFailure, Origin } from "./failure.ts";
export { Mismatch } from "./failure.ts";
export type { Result } from "./result.ts";
export type { DuplicateRule, Rule, RuleEntry } from "./rule.ts";
export { RuleTable } from "./rule.ts";
export { Checked, admit, check } from "./admission.ts";
