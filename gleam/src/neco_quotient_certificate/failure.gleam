import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import neco_quotient_certificate/digest.{type DigestChecks}

pub type Condition {
  Decode
  Source
  Coordinate
  Observations
  Digest
  Residual
}

pub const all_conditions = [
  Decode,
  Source,
  Coordinate,
  Observations,
  Digest,
  Residual,
]

pub fn condition_name(condition: Condition) -> String {
  case condition {
    Decode -> "decode"
    Source -> "source"
    Coordinate -> "coordinate"
    Observations -> "observations"
    Digest -> "digest"
    Residual -> "residual"
  }
}

pub fn prerequisite(condition: Condition) -> Option(Condition) {
  case condition {
    Decode | Source -> None
    Digest -> Some(Decode)
    Coordinate | Observations | Residual -> Some(Source)
  }
}

pub type DecodeStage

pub type SourceStage

pub type CoordinateStage

pub type ObservationsStage

pub type ResidualStage

pub type Origin {
  Origin(
    rule_revision: String,
    source_identity: String,
    source_revision: String,
  )
}

pub type ConditionFailure(stage, p) {
  ConditionFailure(
    condition: Condition,
    operation: String,
    expected: String,
    actual: String,
    origin: Origin,
    provenance: p,
  )
}

pub type Prerequisite(failure, children) {
  Failed(failure: failure)
  Established(children: children)
}

pub type CheckResult(failure) {
  CheckMatched
  CheckMismatched(failure: failure)
}

pub fn is_matched(result: CheckResult(failure)) -> Bool {
  case result {
    CheckMatched -> True
    CheckMismatched(_) -> False
  }
}

pub type SourceChecks(p) {
  SourceChecks(
    coordinate: CheckResult(ConditionFailure(CoordinateStage, p)),
    observations: CheckResult(ConditionFailure(ObservationsStage, p)),
    residual: CheckResult(ConditionFailure(ResidualStage, p)),
  )
}

pub fn source_all_matched(checks: SourceChecks(p)) -> Bool {
  is_matched(checks.coordinate)
  && is_matched(checks.observations)
  && is_matched(checks.residual)
}

pub type AdmissionChecks(p) {
  AdmissionChecks(
    origin: Origin,
    provenance: p,
    decode: Prerequisite(ConditionFailure(DecodeStage, p), DigestChecks),
    source: Prerequisite(ConditionFailure(SourceStage, p), SourceChecks(p)),
  )
}

pub fn all_matched(checks: AdmissionChecks(p)) -> Bool {
  let decode_ok = case checks.decode {
    Failed(_) -> False
    Established(digests) -> digest.all_matched(digests)
  }
  let source_ok = case checks.source {
    Failed(_) -> False
    Established(source) -> source_all_matched(source)
  }
  decode_ok && source_ok
}

pub opaque type Mismatch(p) {
  Mismatch(checks: AdmissionChecks(p))
}

pub fn to_mismatch(checks: AdmissionChecks(p)) -> Result(Mismatch(p), Nil) {
  case all_matched(checks) {
    True -> Error(Nil)
    False -> Ok(Mismatch(checks))
  }
}

pub fn mismatch_checks(mismatch: Mismatch(p)) -> AdmissionChecks(p) {
  let Mismatch(checks) = mismatch
  checks
}

pub fn mismatch_origin(mismatch: Mismatch(p)) -> Origin {
  mismatch_checks(mismatch).origin
}

pub fn mismatch_provenance(mismatch: Mismatch(p)) -> p {
  mismatch_checks(mismatch).provenance
}

pub type Status(p) {
  Matched
  Mismatched
  UncheckedByDecode(failure: ConditionFailure(DecodeStage, p))
  UncheckedBySource(failure: ConditionFailure(SourceStage, p))
}

fn of_bool(holds: Bool) -> Status(p) {
  case holds {
    True -> Matched
    False -> Mismatched
  }
}

pub fn status_at(
  checks: AdmissionChecks(p),
  condition: Condition,
) -> Status(p) {
  case condition {
    Decode ->
      case checks.decode {
        Failed(_) -> Mismatched
        Established(_) -> Matched
      }
    Source ->
      case checks.source {
        Failed(_) -> Mismatched
        Established(_) -> Matched
      }
    Digest ->
      case checks.decode {
        Failed(failure) -> UncheckedByDecode(failure)
        Established(digests) -> of_bool(digest.all_matched(digests))
      }
    Coordinate ->
      case checks.source {
        Failed(failure) -> UncheckedBySource(failure)
        Established(source) -> of_bool(is_matched(source.coordinate))
      }
    Observations ->
      case checks.source {
        Failed(failure) -> UncheckedBySource(failure)
        Established(source) -> of_bool(is_matched(source.observations))
      }
    Residual ->
      case checks.source {
        Failed(failure) -> UncheckedBySource(failure)
        Established(source) -> of_bool(is_matched(source.residual))
      }
  }
}

pub fn mismatch_status_at(
  mismatch: Mismatch(p),
  condition: Condition,
) -> Status(p) {
  status_at(mismatch_checks(mismatch), condition)
}

pub fn describe(mismatch: Mismatch(p)) -> String {
  let checks = mismatch_checks(mismatch)
  let failed =
    all_conditions
    |> list.filter(fn(condition) {
      case status_at(checks, condition) {
        Mismatched -> True
        _ -> False
      }
    })
    |> list.map(condition_name)
  string.concat([
    "admit failed at ",
    string.join(failed, ", "),
    ": rule ",
    checks.origin.rule_revision,
    ", source ",
    checks.origin.source_identity,
    "@",
    checks.origin.source_revision,
  ])
}

pub fn reject_decode(
  decode: ConditionFailure(DecodeStage, p),
  origin: Origin,
  provenance: p,
  source: Prerequisite(ConditionFailure(SourceStage, p), SourceChecks(p)),
) -> Mismatch(p) {
  Mismatch(AdmissionChecks(
    origin:,
    provenance:,
    decode: Failed(decode),
    source:,
  ))
}
