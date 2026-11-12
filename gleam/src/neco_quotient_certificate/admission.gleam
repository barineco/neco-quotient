import gleam/string
import neco_quotient_certificate/certificate.{
  type Certificate, type Expected, residual_values, same_residuals,
}
import neco_quotient_certificate/digest.{type ProjectionDigests}
import neco_quotient_certificate/failure.{
  type AdmissionChecks, type CheckResult, type Condition, type ConditionFailure,
  type CoordinateStage, type DecodeStage, type Mismatch, type ObservationsStage,
  type Origin, type Prerequisite, type ResidualStage, type SourceChecks,
  type SourceStage, AdmissionChecks, CheckMatched, CheckMismatched, Coordinate,
  Decode, Established, Failed, Observations, Origin, Residual, Source,
  SourceChecks,
}
import neco_quotient_certificate/rule_table.{type Rule, type RuleTable}
import neco_quotient_certificate/source.{type SourceRef}

const operation = "admit"

const table_expectation = "rule in table"

pub opaque type Checked(s, rev, c, obs, r, e) {
  Checked(
    RuleTable(s, rev, c, obs, e),
    Certificate(s, rev, c, obs, r, e),
    Expected(s, rev, c, obs, r),
    ProjectionDigests,
  )
}

pub fn certificate(
  checked: Checked(s, rev, c, obs, r, e),
) -> Certificate(s, rev, c, obs, r, e) {
  let Checked(_, certificate, _, _) = checked
  certificate
}

pub fn expected(
  checked: Checked(s, rev, c, obs, r, e),
) -> Expected(s, rev, c, obs, r) {
  let Checked(_, _, expected, _) = checked
  expected
}

pub fn source(checked: Checked(s, rev, c, obs, r, e)) -> SourceRef(s, rev) {
  let Checked(_, certificate, _, _) = checked
  certificate.source
}

pub fn recomputed(checked: Checked(s, rev, c, obs, r, e)) -> ProjectionDigests {
  let Checked(_, _, _, recomputed) = checked
  recomputed
}

type Evaluation(p) {
  DecodeRejected(mismatch: Mismatch(p))
  RuleApplied(checks: AdmissionChecks(p), recomputed: ProjectionDigests)
}

fn evaluate(
  table: RuleTable(s, rev, c, obs, e),
  certificate: Certificate(s, rev, c, obs, r, e),
  expected: Expected(s, rev, c, obs, r),
  provenance: p,
  show_identity: fn(s) -> String,
  show_revision: fn(rev) -> String,
) -> Evaluation(p) {
  let origin = origin_of(certificate, show_identity, show_revision)
  let source =
    source_branch(
      certificate,
      expected,
      origin,
      provenance,
      show_identity,
      show_revision,
    )
  case select_rule(table, certificate, expected, origin, provenance) {
    Ok(rule) -> {
      let recomputed = run_rule(rule, certificate)
      RuleApplied(
        checks: AdmissionChecks(
          origin:,
          provenance:,
          decode: Established(digest.check(recomputed, certificate.digests)),
          source:,
        ),
        recomputed:,
      )
    }
    Error(decode_failure) ->
      DecodeRejected(failure.reject_decode(
        decode_failure,
        origin,
        provenance,
        source,
      ))
  }
}

pub fn check(
  table: RuleTable(s, rev, c, obs, e),
  certificate: Certificate(s, rev, c, obs, r, e),
  expected: Expected(s, rev, c, obs, r),
  provenance: p,
  show_identity: fn(s) -> String,
  show_revision: fn(rev) -> String,
) -> AdmissionChecks(p) {
  case
    evaluate(
      table,
      certificate,
      expected,
      provenance,
      show_identity,
      show_revision,
    )
  {
    DecodeRejected(mismatch) -> failure.mismatch_checks(mismatch)
    RuleApplied(checks:, ..) -> checks
  }
}

pub fn admit(
  table: RuleTable(s, rev, c, obs, e),
  certificate: Certificate(s, rev, c, obs, r, e),
  expected: Expected(s, rev, c, obs, r),
  provenance: p,
  show_identity: fn(s) -> String,
  show_revision: fn(rev) -> String,
) -> Result(Checked(s, rev, c, obs, r, e), Mismatch(p)) {
  case
    evaluate(
      table,
      certificate,
      expected,
      provenance,
      show_identity,
      show_revision,
    )
  {
    DecodeRejected(mismatch) -> Error(mismatch)
    RuleApplied(checks:, recomputed:) ->
      case failure.to_mismatch(checks) {
        Ok(mismatch) -> Error(mismatch)
        Error(Nil) -> Ok(Checked(table, certificate, expected, recomputed))
      }
  }
}

fn run_rule(
  rule: Rule(s, rev, c, obs, e),
  certificate: Certificate(s, rev, c, obs, r, e),
) -> ProjectionDigests {
  rule(
    certificate.source,
    certificate.coordinate,
    certificate.observations,
    certificate.evidence,
  )
}

fn origin_of(
  certificate: Certificate(s, rev, c, obs, r, e),
  show_identity: fn(s) -> String,
  show_revision: fn(rev) -> String,
) -> Origin {
  Origin(
    rule_revision: certificate.rule_revision,
    source_identity: show_identity(certificate.source.identity),
    source_revision: show_revision(certificate.source.revision),
  )
}

fn select_rule(
  table: RuleTable(s, rev, c, obs, e),
  certificate: Certificate(s, rev, c, obs, r, e),
  expected: Expected(s, rev, c, obs, r),
  origin: Origin,
  provenance: p,
) -> Result(Rule(s, rev, c, obs, e), ConditionFailure(DecodeStage, p)) {
  case certificate.rule_revision == expected.rule_revision {
    False ->
      Error(decode_failure(
        origin,
        provenance,
        expected.rule_revision,
        certificate.rule_revision,
      ))
    True ->
      case rule_table.lookup(table, certificate.rule_revision) {
        Ok(rule) -> Ok(rule)
        Error(Nil) ->
          Error(decode_failure(
            origin,
            provenance,
            table_expectation,
            certificate.rule_revision,
          ))
      }
  }
}

fn source_branch(
  certificate: Certificate(s, rev, c, obs, r, e),
  expected: Expected(s, rev, c, obs, r),
  origin: Origin,
  provenance: p,
  show_identity: fn(s) -> String,
  show_revision: fn(rev) -> String,
) -> Prerequisite(ConditionFailure(SourceStage, p), SourceChecks(p)) {
  case certificate.source == expected.source {
    True ->
      Established(SourceChecks(
        coordinate: check_result(
          certificate.coordinate == expected.coordinate,
          coordinate_failure(
            origin,
            provenance,
            string.inspect(expected.coordinate),
            string.inspect(certificate.coordinate),
          ),
        ),
        observations: check_result(
          certificate.observations == expected.observations,
          observations_failure(
            origin,
            provenance,
            string.inspect(expected.observations),
            string.inspect(certificate.observations),
          ),
        ),
        residual: check_result(
          same_residuals(certificate.residuals, expected.residuals),
          residual_failure(
            origin,
            provenance,
            string.inspect(residual_values(expected.residuals)),
            string.inspect(residual_values(certificate.residuals)),
          ),
        ),
      ))
    False ->
      Failed(source_failure(
        origin,
        provenance,
        source_text(expected.source, show_identity, show_revision),
        source_text(certificate.source, show_identity, show_revision),
      ))
  }
}

fn check_result(
  holds: Bool,
  failure: ConditionFailure(stage, p),
) -> CheckResult(ConditionFailure(stage, p)) {
  case holds {
    True -> CheckMatched
    False -> CheckMismatched(failure)
  }
}

fn decode_failure(
  origin: Origin,
  provenance: p,
  expected: String,
  actual: String,
) -> ConditionFailure(DecodeStage, p) {
  condition_failure(Decode, origin, provenance, expected, actual)
}

fn source_failure(
  origin: Origin,
  provenance: p,
  expected: String,
  actual: String,
) -> ConditionFailure(SourceStage, p) {
  condition_failure(Source, origin, provenance, expected, actual)
}

fn coordinate_failure(
  origin: Origin,
  provenance: p,
  expected: String,
  actual: String,
) -> ConditionFailure(CoordinateStage, p) {
  condition_failure(Coordinate, origin, provenance, expected, actual)
}

fn observations_failure(
  origin: Origin,
  provenance: p,
  expected: String,
  actual: String,
) -> ConditionFailure(ObservationsStage, p) {
  condition_failure(Observations, origin, provenance, expected, actual)
}

fn residual_failure(
  origin: Origin,
  provenance: p,
  expected: String,
  actual: String,
) -> ConditionFailure(ResidualStage, p) {
  condition_failure(Residual, origin, provenance, expected, actual)
}

fn condition_failure(
  condition: Condition,
  origin: Origin,
  provenance: p,
  expected: String,
  actual: String,
) -> ConditionFailure(stage, p) {
  failure.ConditionFailure(
    condition: condition,
    operation: operation,
    expected: expected,
    actual: actual,
    origin: origin,
    provenance: provenance,
  )
}

fn source_text(
  source: SourceRef(s, rev),
  show_identity: fn(s) -> String,
  show_revision: fn(rev) -> String,
) -> String {
  show_identity(source.identity) <> "@" <> show_revision(source.revision)
}
