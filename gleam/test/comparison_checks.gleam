import corpus
import gleam/bit_array
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/string
import json_string
import neco_quotient_certificate/admission
import neco_quotient_certificate/certificate.{residual_values, same_residuals}
import neco_quotient_certificate/digest.{
  type ProjectionDigest, type ProjectionResult, CertificateOnly, CrossLanguage,
  Different, Matched, ProjectionDigest, RecomputedOnly, WithinRuntime,
}
import neco_quotient_certificate/failure.{
  type AdmissionChecks, type CheckResult, type ConditionFailure, type Origin,
  type SourceChecks, CheckMatched, CheckMismatched, Established, Failed,
}
import neco_quotient_certificate/rule_table.{type RuleTable}

pub type Json {
  JBool(Bool)
  JString(String)
  JArray(List(Json))
  JObject(List(#(String, Json)))
}

pub fn run() {
  byte_for_byte_projection_matches_lean_outcomes()
  versioned_residual_set_api_cases_match_lean_outcomes()
  admit_accepts_exactly_the_checks_without_failures()
  failures_keep_input_provenance_and_certificate_origin()
  accepted_certificates_return_certificate_and_recomputed_digests()
  residuals_and_digests_are_in_normal_form()
  digests_equal_independent_recomputation_except_intended_corruptions()
  table_order_does_not_change_outcomes()
  sha256_matches_fips_vectors()
  canonical_string_matches_the_normal_form()
}

fn identity(text: String) -> String {
  text
}

fn checks_of(
  table: RuleTable(String, String, String, String, String),
  row: corpus.Row,
) -> AdmissionChecks(String) {
  admission.check(
    table,
    row.certificate,
    row.expected,
    row.provenance,
    identity,
    identity,
  )
}

fn accepted(checks: AdmissionChecks(String)) -> Bool {
  case failure.to_mismatch(checks) {
    Ok(_) -> False
    Error(Nil) -> True
  }
}

fn render(json: Json) -> String {
  case json {
    JBool(True) -> "true"
    JBool(False) -> "false"
    JString(text) -> json_string.string_literal(text)
    JArray(items) -> "[" <> string.join(list.map(items, render), ",") <> "]"
    JObject(entries) -> {
      let sorted =
        list.sort(entries, fn(left, right) { string.compare(left.0, right.0) })
      let members =
        list.map(sorted, fn(entry) {
          json_string.string_literal(entry.0) <> ":" <> render(entry.1)
        })
      "{" <> string.join(members, ",") <> "}"
    }
  }
}

fn origin_json(origin: Origin) -> Json {
  JObject([
    #("rule_revision", JString(origin.rule_revision)),
    #("source_identity", JString(origin.source_identity)),
    #("source_revision", JString(origin.source_revision)),
  ])
}

fn failure_json(condition_failure: ConditionFailure(stage, String)) -> Json {
  JObject([
    #("operation", JString(condition_failure.operation)),
    #("origin", origin_json(condition_failure.origin)),
  ])
}

fn mismatched_json(condition_failure: ConditionFailure(stage, String)) -> Json {
  JObject([
    #("status", JString("mismatched")),
    #("failure", failure_json(condition_failure)),
  ])
}

fn unchecked_json(
  prerequisite: String,
  condition_failure: ConditionFailure(stage, String),
) -> Json {
  JObject([
    #("status", JString("unchecked")),
    #("prerequisite", JString(prerequisite)),
    #("failure", failure_json(condition_failure)),
  ])
}

fn matched_json() -> Json {
  JObject([#("status", JString("matched"))])
}

fn child_json(
  checks: AdmissionChecks(String),
  select: fn(SourceChecks(String)) ->
    CheckResult(ConditionFailure(stage, String)),
) -> Json {
  case checks.source {
    Failed(condition_failure) -> unchecked_json("source", condition_failure)
    Established(source) ->
      case select(source) {
        CheckMatched -> matched_json()
        CheckMismatched(condition_failure) -> mismatched_json(condition_failure)
      }
  }
}

fn digest_json(value: ProjectionDigest) -> Json {
  let scope = case value.scope {
    WithinRuntime(payload) -> JObject([#("within_runtime", JString(payload))])
    CrossLanguage(payload) -> JObject([#("cross_language", JString(payload))])
  }
  JObject([#("digest", JString(value.digest)), #("scope", scope)])
}

fn projection_json(result: ProjectionResult) -> Json {
  case result {
    Matched(value) ->
      JObject([#("result", JString("matched")), #("value", digest_json(value))])
    CertificateOnly(actual) ->
      JObject([
        #("result", JString("certificate_only")),
        #("actual", digest_json(actual)),
      ])
    RecomputedOnly(expected) ->
      JObject([
        #("result", JString("recomputed_only")),
        #("expected", digest_json(expected)),
      ])
    Different(expected, actual) ->
      JObject([
        #("result", JString("different")),
        #("expected", digest_json(expected)),
        #("actual", digest_json(actual)),
      ])
  }
}

fn digest_condition_json(checks: AdmissionChecks(String)) -> Json {
  case checks.decode {
    Failed(condition_failure) -> unchecked_json("decode", condition_failure)
    Established(results) ->
      JObject([
        #("status", case digest.all_matched(results) {
          True -> JString("matched")
          False -> JString("mismatched")
        }),
        #(
          "projections",
          JObject(
            dict.to_list(results)
            |> list.map(fn(entry) { #(entry.0, projection_json(entry.1)) }),
          ),
        ),
      ])
  }
}

fn conditions_json(checks: AdmissionChecks(String)) -> Json {
  JObject([
    #("decode", case checks.decode {
      Failed(condition_failure) -> mismatched_json(condition_failure)
      Established(_) -> matched_json()
    }),
    #("source", case checks.source {
      Failed(condition_failure) -> mismatched_json(condition_failure)
      Established(_) -> matched_json()
    }),
    #("digest", digest_condition_json(checks)),
    #("coordinate", child_json(checks, fn(source) { source.coordinate })),
    #("observations", child_json(checks, fn(source) { source.observations })),
    #("residual", child_json(checks, fn(source) { source.residual })),
  ])
}

fn outcome_text(
  table: RuleTable(String, String, String, String, String),
  row: corpus.Row,
) -> String {
  let checks = checks_of(table, row)
  render(
    JObject([
      #("accepted", JBool(accepted(checks))),
      #("conditions", conditions_json(checks)),
      #("name", JString(row.name)),
      #(
        "residuals",
        JArray(
          row.certificate.residuals
          |> residual_values
          |> list.sort(string.compare)
          |> list.map(JString),
        ),
      ),
    ]),
  )
}

fn projection_with(
  table: RuleTable(String, String, String, String, String),
  rows: List(corpus.Row),
) -> String {
  "[" <> string.join(list.map(rows, outcome_text(table, _)), ",") <> "]"
}

fn byte_for_byte_projection_matches_lean_outcomes() {
  let assert Ok(expected) =
    bit_array.to_string(corpus.read_bytes("lean-outcomes.json"))
  assert projection_with(corpus.table(), corpus.rows()) == expected
}

fn versioned_residual_set_api_cases_match_lean_outcomes() {
  let rows = corpus.rows_from("residual-set-api-cases-v1.json")
  let assert Ok(expected) =
    bit_array.to_string(corpus.read_bytes("residual-set-api-outcomes-v1.json"))
  assert list.length(rows) == 2
  assert projection_with(corpus.table(), rows) == expected
  let assert [order_and_duplicates, membership] = rows
  assert same_residuals(
    order_and_duplicates.certificate.residuals,
    order_and_duplicates.expected.residuals,
  )
  assert !same_residuals(
    membership.certificate.residuals,
    membership.expected.residuals,
  )
  let assert Error(mismatch) =
    admission.admit(
      corpus.table(),
      membership.certificate,
      membership.expected,
      membership.provenance,
      identity,
      identity,
    )
  assert failure.mismatch_status_at(mismatch, failure.Residual)
    == failure.Mismatched
}

fn admit_accepts_exactly_the_checks_without_failures() {
  list.each(corpus.rows(), fn(row) {
    let checks = checks_of(corpus.table(), row)
    let outcome =
      admission.admit(
        corpus.table(),
        row.certificate,
        row.expected,
        row.provenance,
        identity,
        identity,
      )
    assert accepted(checks)
      == case outcome {
        Ok(_) -> True
        Error(_) -> False
      }
  })
}

fn failures_keep_input_provenance_and_certificate_origin() {
  list.each(corpus.rows(), fn(row) {
    case
      admission.admit(
        corpus.table(),
        row.certificate,
        row.expected,
        row.provenance,
        identity,
        identity,
      )
    {
      Ok(_) -> Nil
      Error(mismatch) -> {
        assert failure.mismatch_provenance(mismatch) == row.provenance
        assert row.provenance == "caller/" <> row.name
        assert failure.mismatch_origin(mismatch)
          == failure.Origin(
            rule_revision: row.certificate.rule_revision,
            source_identity: row.certificate.source.identity,
            source_revision: row.certificate.source.revision,
          )
      }
    }
  })
}

fn accepted_certificates_return_certificate_and_recomputed_digests() {
  list.each(corpus.rows(), fn(row) {
    case
      admission.admit(
        corpus.table(),
        row.certificate,
        row.expected,
        row.provenance,
        identity,
        identity,
      )
    {
      Ok(checked) -> {
        assert admission.certificate(checked) == row.certificate
        assert admission.recomputed(checked) == row.certificate.digests
      }
      Error(_) -> Nil
    }
  })
}

fn residuals_and_digests_are_in_normal_form() {
  list.each(corpus.rows(), fn(row) {
    let certificate_residuals = residual_values(row.certificate.residuals)
    let expected_residuals = residual_values(row.expected.residuals)
    assert list.sort(certificate_residuals, string.compare)
      == certificate_residuals
    assert list.sort(expected_residuals, string.compare) == expected_residuals
  })
}

fn digests_equal_independent_recomputation_except_intended_corruptions() {
  list.each(corpus.rows(), fn(row) {
    case dict.get(row.certificate.digests, "evidence") {
      Error(Nil) -> Nil
      Ok(digest) -> {
        let independent =
          corpus.sha256_hex(
            bit_array.from_string(json_string.string_literal(
              row.certificate.evidence,
            )),
          )
        let intended =
          list.contains(
            [
              "digest",
              "source_with_dependents",
              "source_and_digest_fail",
              "all_independent_fail",
              "digest_value_and_certificate_only",
            ],
            row.name,
          )
        let matches = digest.digest == independent
        assert matches == !intended
      }
    }
  })
}

fn table_order_does_not_change_outcomes() {
  let rows = corpus.rows()
  let reference = projection_with(corpus.table(), rows)
  let other = fn(_source, _coordinate, _observations, _evidence) {
    dict.from_list([
      #("evidence", ProjectionDigest("0", CrossLanguage("other"))),
    ])
  }
  let entries = [
    #(corpus.revision, corpus.comparison_rule),
    #("other/sha256@1", other),
    #("third/sha256@1", other),
  ]
  let orders = [
    entries,
    list.reverse(entries),
    list.append(list.drop(entries, 1), list.take(entries, 1)),
  ]
  list.each(orders, fn(order) {
    let assert Ok(table) = rule_table.new(order)
    assert projection_with(table, rows) == reference
  })
}

fn sha256_matches_fips_vectors() {
  assert corpus.sha256_hex(bit_array.from_string(""))
    == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  assert corpus.sha256_hex(bit_array.from_string("abc"))
    == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  assert corpus.sha256_hex(bit_array.from_string(
      "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
    ))
    == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
}

fn canonical_string_matches_the_normal_form() {
  let input =
    string.concat([
      "\"",
      "\\",
      "\n",
      "\r",
      "\t",
      "\u{8}",
      "\u{c}",
      "\u{0}",
      "\u{1f}",
      "/",
      "\u{7f}",
      "日本語",
    ])
  let expected =
    string.concat([
      "\"",
      "\\\"",
      "\\\\",
      "\\n",
      "\\r",
      "\\t",
      "\\b",
      "\\f",
      "\\u0000",
      "\\u001f",
      "/",
      "\u{7f}",
      "日本語",
      "\"",
    ])
  let literal = json_string.string_literal(input)
  assert literal == expected
  let decoded =
    decode.run(corpus.parse_json(bit_array.from_string(literal)), decode.string)
  assert decoded == Ok(input)
}
