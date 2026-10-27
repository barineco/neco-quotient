import fixtures
import gleam/int
import gleam/list
import gleam/string
import neco_quotient_certificate/admission
import neco_quotient_certificate/certificate.{Certificate, Expected}
import neco_quotient_certificate/digest.{
  CrossLanguage, ProjectionDigest, WithinRuntime,
}
import neco_quotient_certificate/failure
import neco_quotient_certificate/rule_table

pub type Caller {
  Caller(name: String)
}

pub fn run() {
  duplicate_revisions_are_rejected_at_construction()
  first_reappearing_revision_is_reported()
  each_stage_is_reported_before_all_later_stages()
  each_stage_alone_is_reported_at_its_stage()
  decode_reports_version_before_table_lookup()
  unknown_revision_is_reported_at_decode()
  failure_keeps_provenance_and_certificate_origin()
  describe_names_operation_stage_and_origin()
  accepted_certificate_exposes_observations()
  digest_comparison_covers_scope_payload_projection_and_order()
  constructed_table_keeps_its_rules()
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

fn each_stage_is_reported_before_all_later_stages() {
  list.index_map(fixtures.stages, fn(stage, index) { #(stage, index) })
  |> list.each(fn(pair) {
    let #(stage, index) = pair
    let broken =
      list.drop(fixtures.stages, index)
      |> list.fold(fixtures.certificate(), fixtures.break_stage)
    let assert Error(mismatch) =
      admit(fixtures.table(), broken, fixtures.expected())
    assert mismatch.stage == stage
  })
}

fn each_stage_alone_is_reported_at_its_stage() {
  list.each(fixtures.stages, fn(stage) {
    let broken = fixtures.break_stage(fixtures.certificate(), stage)
    let assert Error(mismatch) =
      admit(fixtures.table(), broken, fixtures.expected())
    assert mismatch.stage == stage
  })
}

fn decode_reports_version_before_table_lookup() {
  let cert = Certificate(..fixtures.certificate(), rule_revision: "rule@2")
  let assert Error(mismatch) =
    admit(fixtures.table(), cert, fixtures.expected())
  assert mismatch.stage == failure.Decode
  assert mismatch.expected == "rule@1"
  assert mismatch.actual == "rule@2"
}

fn unknown_revision_is_reported_at_decode() {
  let cert = Certificate(..fixtures.certificate(), rule_revision: "rule@9")
  let expected = Expected(..fixtures.expected(), rule_revision: "rule@9")
  let assert Error(mismatch) = admit(fixtures.table(), cert, expected)
  assert mismatch.stage == failure.Decode
  assert mismatch.expected == "rule in table"
  assert mismatch.actual == "rule@9"
}

fn failure_keeps_provenance_and_certificate_origin() {
  let broken = fixtures.break_stage(fixtures.certificate(), failure.Source)
  let assert Error(mismatch) =
    admit(fixtures.table(), broken, fixtures.expected())
  assert mismatch.provenance == Caller("caller")
  assert mismatch.origin
    == failure.Origin(
      rule_revision: "rule@1",
      source_identity: "src",
      source_revision: "8",
    )
  assert mismatch.contributing == []
}

fn describe_names_operation_stage_and_origin() {
  let broken = fixtures.break_stage(fixtures.certificate(), failure.Residual)
  let assert Error(mismatch) =
    admit(fixtures.table(), broken, fixtures.expected())
  let text = failure.describe(mismatch)
  assert string.starts_with(text, "admit failed at stage residual")
  assert string.contains(text, "rule rule@1")
  assert string.contains(text, "source src@7")
}

fn accepted_certificate_exposes_observations() {
  let cert = fixtures.certificate()
  let assert Ok(checked) = admit(fixtures.table(), cert, fixtures.expected())
  assert admission.certificate(checked) == cert
  assert admission.source(checked) == fixtures.source()
  assert admission.recomputed(checked) == cert.digests
  Nil
}

fn digest_comparison_covers_scope_payload_projection_and_order() {
  let cert = fixtures.certificate()
  let digests = cert.digests
  let variants = [
    list.reverse(digests),
    list.drop(digests, 1),
    list.append(digests, list.take(digests, 1)),
    list.map(digests, fn(digest) {
      ProjectionDigest(..digest, scope: CrossLanguage("fixture@2"))
    }),
    list.map(digests, fn(digest) {
      ProjectionDigest(..digest, scope: WithinRuntime("fixture@1"))
    }),
    list.map(digests, fn(digest) {
      ProjectionDigest(..digest, digest: "changed")
    }),
    list.map(digests, fn(digest) {
      ProjectionDigest(..digest, projection: "changed")
    }),
  ]
  let assert Ok(_) = admit(fixtures.table(), cert, fixtures.expected())
  list.each(variants, fn(changed) {
    let assert Error(mismatch) =
      admit(
        fixtures.table(),
        Certificate(..cert, digests: changed),
        fixtures.expected(),
      )
    assert mismatch.stage == failure.Digest
  })
}

fn constructed_table_keeps_its_rules() {
  let assert Ok(first) =
    rule_table.new([#(fixtures.revision, fixtures.semantics("default"))])
  let entries = [#(fixtures.revision, fixtures.semantics("other"))]
  let assert Ok(_) = rule_table.new(entries)
  let assert Ok(_) = admit(first, fixtures.certificate(), fixtures.expected())
  Nil
}
