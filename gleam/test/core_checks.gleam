import fixtures
import gleam/dict
import gleam/int
import gleam/list
import neco_quotient_certificate/admission
import neco_quotient_certificate/certificate.{Certificate, Expected}
import neco_quotient_certificate/digest.{
  CertificateOnly, CrossLanguage, Different, Matched, ProjectionDigest,
  RecomputedOnly, WithinRuntime,
}
import neco_quotient_certificate/failure.{
  Coordinate, Decode, Digest, Failed, Observations, Residual, Source,
}
import neco_quotient_certificate/rule_table

pub type Caller {
  Caller(name: String)
}

pub fn run() {
  duplicate_revisions_are_rejected_at_construction()
  first_reappearing_revision_is_reported()
  independent_children_are_reported_together()
  decode_failure_leaves_digest_unchecked()
  source_failure_leaves_children_unchecked()
  each_break_is_reported_at_its_condition()
  digest_results_are_classified_by_name()
  digest_order_does_not_change_outcomes()
  decode_reports_version_before_table_lookup()
  unknown_revision_is_reported_at_decode()
  failure_keeps_provenance_and_certificate_origin()
  failures_hold_their_own_condition()
  describe_names_failed_conditions()
  accepted_certificate_exposes_checked_parts()
  constructed_table_keeps_its_rules()
}

fn check(
  table: rule_table.RuleTable(String, Int, Int, Int, Int),
  cert: fixtures.Fixture,
  expected: fixtures.FixtureExpected,
) -> failure.AdmissionChecks(Caller) {
  admission.check(
    table,
    cert,
    expected,
    Caller("caller"),
    fn(text) { text },
    int.to_string,
  )
}

fn admit(
  table: rule_table.RuleTable(String, Int, Int, Int, Int),
  cert: fixtures.Fixture,
  expected: fixtures.FixtureExpected,
) -> Result(
  admission.Checked(String, Int, Int, Int, Int, Int),
  failure.Mismatch(Caller),
) {
  admission.admit(
    table,
    cert,
    expected,
    Caller("caller"),
    fn(text) { text },
    int.to_string,
  )
}

fn duplicate_revisions_are_rejected_at_construction() {
  let rule = fixtures.semantics("default")
  let assert Error(rule_table.DuplicateRule("rule@1")) =
    rule_table.new([
      #("rule@1", rule),
      #("rule@2", rule),
      #("rule@1", rule),
    ])
  let assert Ok(_) = rule_table.new([#("rule@1", rule), #("rule@2", rule)])
  Nil
}

fn first_reappearing_revision_is_reported() {
  let rule = fixtures.semantics("default")
  let assert Error(rule_table.DuplicateRule("b")) =
    rule_table.new([
      #("a", rule),
      #("b", rule),
      #("b", rule),
      #("a", rule),
    ])
  Nil
}

fn independent_children_are_reported_together() {
  let broken =
    fixtures.break_residual(fixtures.break_coordinate(fixtures.certificate()))
  let checks = check(fixtures.table(), broken, fixtures.expected())
  assert failure.status_at(checks, Coordinate) == failure.Mismatched
  assert failure.status_at(checks, Residual) == failure.Mismatched
  assert failure.status_at(checks, Observations) == failure.Matched
  assert failure.status_at(checks, Source) == failure.Matched
  let assert Error(mismatch) =
    admit(fixtures.table(), broken, fixtures.expected())
  assert failure.mismatch_status_at(mismatch, Residual) == failure.Mismatched
  assert failure.mismatch_status_at(mismatch, Coordinate) == failure.Mismatched
}

fn decode_failure_leaves_digest_unchecked() {
  let broken = fixtures.break_decode(fixtures.certificate())
  let checks = check(fixtures.table(), broken, fixtures.expected())
  assert failure.status_at(checks, Decode) == failure.Mismatched
  assert failure.status_at(checks, Source) == failure.Matched
  let assert failure.UncheckedByDecode(decode_failure) =
    failure.status_at(checks, Digest)
  assert decode_failure.expected == "rule@1"
  assert decode_failure.actual == "rule@2"
  assert failure.status_at(checks, Coordinate) == failure.Matched
}

fn source_failure_leaves_children_unchecked() {
  let broken = fixtures.break_source(fixtures.certificate())
  let checks = check(fixtures.table(), broken, fixtures.expected())
  assert failure.status_at(checks, Source) == failure.Mismatched
  let assert failure.UncheckedBySource(source_failure) =
    failure.status_at(checks, Coordinate)
  assert source_failure.expected == "src@7"
  assert source_failure.actual == "src@8"
  let assert failure.UncheckedBySource(_) =
    failure.status_at(checks, Observations)
  let assert failure.UncheckedBySource(_) = failure.status_at(checks, Residual)
  assert failure.status_at(checks, Decode) == failure.Matched
  assert failure.status_at(checks, Digest) == failure.Mismatched
}

fn each_break_is_reported_at_its_condition() {
  [
    #(fixtures.break_decode, Decode),
    #(fixtures.break_source, Source),
    #(fixtures.break_coordinate, Coordinate),
    #(fixtures.break_observations, Observations),
    #(fixtures.break_digest, Digest),
    #(fixtures.break_residual, Residual),
  ]
  |> list.each(fn(pair) {
    let #(break, condition) = pair
    let assert Error(mismatch) =
      admit(
        fixtures.table(),
        break(fixtures.certificate()),
        fixtures.expected(),
      )
    assert failure.mismatch_status_at(mismatch, condition) == failure.Mismatched
  })
}

fn digest_results_are_classified_by_name() {
  let expected = fixtures.digests()
  let assert Ok(graph) = dict.get(expected, "graph")
  let assert Ok(metadata) = dict.get(expected, "metadata")
  let extra =
    ProjectionDigest(digest: "extra", scope: CrossLanguage("fixture@1"))
  let actual =
    expected
    |> dict.delete("metadata")
    |> dict.insert("extra", extra)
  let checks = digest.check(expected, actual)
  assert dict.get(checks, "graph") == Ok(Matched(graph))
  assert dict.get(checks, "metadata") == Ok(RecomputedOnly(metadata))
  assert dict.get(checks, "extra") == Ok(CertificateOnly(extra))
  let scoped =
    dict.insert(
      expected,
      "graph",
      ProjectionDigest(..graph, scope: WithinRuntime("fixture@1")),
    )
  let assert Ok(Different(_, _)) =
    dict.get(digest.check(expected, scoped), "graph")
  assert dict.get(digest.check(expected, scoped), "metadata")
    == Ok(Matched(metadata))
}

fn digest_order_does_not_change_outcomes() {
  let cert = fixtures.certificate()
  let reversed =
    dict.to_list(cert.digests)
    |> list.reverse
    |> dict.from_list
  assert reversed == cert.digests
  let assert Ok(_) =
    admit(
      fixtures.table(),
      Certificate(..cert, digests: reversed),
      fixtures.expected(),
    )
  let changed =
    dict.insert(
      cert.digests,
      "graph",
      ProjectionDigest(digest: "changed", scope: CrossLanguage("fixture@1")),
    )
  let assert Error(mismatch) =
    admit(
      fixtures.table(),
      Certificate(..cert, digests: changed),
      fixtures.expected(),
    )
  assert failure.mismatch_status_at(mismatch, Digest) == failure.Mismatched
}

fn decode_reports_version_before_table_lookup() {
  let cert = Certificate(..fixtures.certificate(), rule_revision: "rule@2")
  let checks = check(fixtures.table(), cert, fixtures.expected())
  let assert failure.AdmissionChecks(decode: Failed(decode_failure), ..) =
    checks
  assert decode_failure.expected == "rule@1"
  assert decode_failure.actual == "rule@2"
}

fn unknown_revision_is_reported_at_decode() {
  let cert = Certificate(..fixtures.certificate(), rule_revision: "rule@9")
  let expected = Expected(..fixtures.expected(), rule_revision: "rule@9")
  let checks = check(fixtures.table(), cert, expected)
  let assert failure.AdmissionChecks(decode: Failed(decode_failure), ..) =
    checks
  assert decode_failure.expected == "rule in table"
  assert decode_failure.actual == "rule@9"
}

fn failure_keeps_provenance_and_certificate_origin() {
  let broken = fixtures.break_source(fixtures.certificate())
  let assert Error(mismatch) =
    admit(fixtures.table(), broken, fixtures.expected())
  assert failure.mismatch_provenance(mismatch) == Caller("caller")
  assert failure.mismatch_origin(mismatch)
    == failure.Origin(
      rule_revision: "rule@1",
      source_identity: "src",
      source_revision: "8",
    )
}

fn failures_hold_their_own_condition() {
  let table = fixtures.table()
  let expected = fixtures.expected()
  let unknown =
    check(
      table,
      Certificate(..fixtures.certificate(), rule_revision: "rule@9"),
      Expected(..expected, rule_revision: "rule@9"),
    )
  let assert failure.AdmissionChecks(decode: Failed(unknown_failure), ..) =
    unknown
  assert unknown_failure.condition == Decode
  let version =
    check(table, fixtures.break_decode(fixtures.certificate()), expected)
  let assert failure.AdmissionChecks(decode: Failed(version_failure), ..) =
    version
  assert version_failure.condition == Decode
  let source =
    check(table, fixtures.break_source(fixtures.certificate()), expected)
  let assert failure.AdmissionChecks(source: Failed(source_failure), ..) =
    source
  assert source_failure.condition == Source
  let assert failure.UncheckedBySource(by_source) =
    failure.status_at(source, Coordinate)
  assert by_source.condition == Source
  let assert failure.UncheckedByDecode(by_decode) =
    failure.status_at(version, Digest)
  assert by_decode.condition == Decode
  let children =
    check(
      table,
      fixtures.break_residual(
        fixtures.break_observations(
          fixtures.break_coordinate(fixtures.certificate()),
        ),
      ),
      expected,
    )
  let assert failure.AdmissionChecks(
    source: failure.Established(failure.SourceChecks(
      coordinate: failure.CheckMismatched(coordinate_failure),
      observations: failure.CheckMismatched(observations_failure),
      residual: failure.CheckMismatched(residual_failure),
    )),
    ..,
  ) = children
  let extracted = [
    #(Coordinate, coordinate_failure.condition),
    #(Observations, observations_failure.condition),
    #(Residual, residual_failure.condition),
  ]
  list.each(extracted, fn(pair) {
    assert pair.0 == pair.1
  })
  let carried = [
    unknown_failure.condition,
    source_failure.condition,
    coordinate_failure.condition,
    observations_failure.condition,
    residual_failure.condition,
  ]
  assert carried == [Decode, Source, Coordinate, Observations, Residual]
}

fn describe_names_failed_conditions() {
  let broken = fixtures.break_residual(fixtures.certificate())
  let assert Error(mismatch) =
    admit(fixtures.table(), broken, fixtures.expected())
  assert failure.describe(mismatch)
    == "admit failed at residual: rule rule@1, source src@7"
}

fn accepted_certificate_exposes_checked_parts() {
  let cert = fixtures.certificate()
  let assert Ok(checked) = admit(fixtures.table(), cert, fixtures.expected())
  assert admission.certificate(checked) == cert
  assert admission.expected(checked) == fixtures.expected()
  assert admission.source(checked) == fixtures.source()
  assert admission.recomputed(checked) == cert.digests
  Nil
}

fn constructed_table_keeps_its_rules() {
  let assert Ok(first) =
    rule_table.new([#(fixtures.revision, fixtures.semantics("default"))])
  let entries = [#(fixtures.revision, fixtures.semantics("other"))]
  let assert Ok(_) = rule_table.new(entries)
  let assert Ok(_) = admit(first, fixtures.certificate(), fixtures.expected())
  Nil
}
