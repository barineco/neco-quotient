import corpus
import gleam/bit_array
import gleam/dynamic/decode
import gleam/list
import gleam/string
import json_string
import neco_quotient_certificate/admission
import neco_quotient_certificate/certificate.{residual_values, same_residuals}
import neco_quotient_certificate/digest.{CrossLanguage, ProjectionDigest}
import neco_quotient_certificate/failure
import neco_quotient_certificate/rule_table.{type RuleTable}

type Checked =
  admission.Checked(String, String, String, String, String, String)

type Outcome =
  Result(Checked, failure.Mismatch(String))

pub fn run() {
  byte_for_byte_projection_matches_lean_outcomes()
  versioned_residual_set_api_cases_match_lean_outcomes()
  failures_keep_input_provenance_and_certificate_origin()
  accepted_certificates_return_certificate_and_recomputed_digests()
  corpus_covers_each_stage_and_both_decode_variants()
  residuals_and_digests_are_in_normal_form()
  digests_equal_independent_recomputation_except_intended_corruptions()
  table_order_does_not_change_outcomes()
  constructed_table_keeps_its_rules()
  sha256_matches_fips_vectors()
  canonical_string_matches_the_normal_form()
}

fn identity(text: String) -> String {
  text
}

fn admit_row(
  table: RuleTable(String, String, String, String, String),
  row: corpus.Row,
) -> Outcome {
  admission.admit(
    table,
    row.certificate,
    row.expected,
    row.provenance,
    identity,
    identity,
  )
}

fn outcome_text(row: corpus.Row, outcome: Outcome) -> String {
  let name = json_string.string_literal(row.name)
  let residuals =
    row.certificate.residuals
    |> residual_values
    |> list.sort(string.compare)
    |> list.map(json_string.string_literal)
    |> string.join(",")
  case outcome {
    Ok(_) ->
      "{\"accepted\":true,\"name\":"
      <> name
      <> ",\"residuals\":["
      <> residuals
      <> "]}"
    Error(mismatch) ->
      string.concat([
        "{\"accepted\":false,\"failure\":{\"operation\":",
        json_string.string_literal(mismatch.operation),
        ",\"origin\":{\"rule_revision\":",
        json_string.string_literal(mismatch.origin.rule_revision),
        ",\"source_identity\":",
        json_string.string_literal(mismatch.origin.source_identity),
        ",\"source_revision\":",
        json_string.string_literal(mismatch.origin.source_revision),
        "},\"stage\":",
        json_string.string_literal(failure.stage_name(mismatch.stage)),
        "},\"name\":",
        name,
        ",\"residuals\":[",
        residuals,
        "]",
        "}",
      ])
  }
}

fn outcomes_with(
  table: RuleTable(String, String, String, String, String),
  rows: List(corpus.Row),
) -> List(Outcome) {
  list.map(rows, fn(row) { admit_row(table, row) })
}

fn projection_with(
  table: RuleTable(String, String, String, String, String),
  rows: List(corpus.Row),
) -> String {
  let texts =
    list.map2(rows, outcomes_with(table, rows), fn(row, outcome) {
      outcome_text(row, outcome)
    })
  "[" <> string.join(texts, ",") <> "]"
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
  let assert Error(mismatch) = admit_row(corpus.table(), membership)
  assert failure.stage_name(mismatch.stage) == "residual"
}

fn failures_keep_input_provenance_and_certificate_origin() {
  let rows = corpus.rows()
  let failing =
    list.zip(rows, outcomes_with(corpus.table(), rows))
    |> list.filter_map(fn(pair) {
      case pair {
        #(row, Error(mismatch)) -> Ok(#(row, mismatch))
        #(_, Ok(_)) -> Error(Nil)
      }
    })
  assert list.length(failing) == 7
  list.each(failing, fn(pair) {
    let #(row, mismatch) = pair
    assert mismatch.provenance == row.provenance
    assert row.provenance == "caller/" <> row.name
    assert mismatch.origin
      == failure.Origin(
        rule_revision: row.certificate.rule_revision,
        source_identity: row.certificate.source.identity,
        source_revision: row.certificate.source.revision,
      )
    assert mismatch.contributing == []
  })
}

fn accepted_certificates_return_certificate_and_recomputed_digests() {
  let rows = corpus.rows()
  let accepted =
    list.zip(rows, outcomes_with(corpus.table(), rows))
    |> list.filter_map(fn(pair) {
      case pair {
        #(row, Ok(checked)) -> Ok(#(row, checked))
        #(_, Error(_)) -> Error(Nil)
      }
    })
  assert list.length(accepted) == 2
  list.each(accepted, fn(pair) {
    let #(row, checked) = pair
    assert admission.certificate(checked) == row.certificate
    assert admission.recomputed(checked) == row.certificate.digests
  })
}

fn stage_key(outcome: Outcome) -> String {
  case outcome {
    Ok(_) -> "accepted"
    Error(mismatch) -> failure.stage_name(mismatch.stage)
  }
}

fn corpus_covers_each_stage_and_both_decode_variants() {
  let rows = corpus.rows()
  let outcomes = outcomes_with(corpus.table(), rows)
  let keys = list.map(outcomes, stage_key)
  assert list.sort(keys, string.compare)
    == [
      "accepted",
      "accepted",
      "coordinate",
      "decode",
      "decode",
      "digest",
      "observations",
      "source",
      "source",
    ]
  let decode_expected =
    outcomes
    |> list.filter_map(fn(outcome) {
      case outcome {
        Error(mismatch) ->
          case failure.stage_name(mismatch.stage) {
            "decode" -> Ok(mismatch.expected)
            _ -> Error(Nil)
          }
        Ok(_) -> Error(Nil)
      }
    })
    |> list.sort(string.compare)
  assert decode_expected == ["comparison/sha256@2", "rule in table"]
}

fn residuals_and_digests_are_in_normal_form() {
  list.each(corpus.rows(), fn(row) {
    let certificate_residuals = residual_values(row.certificate.residuals)
    let expected_residuals = residual_values(row.expected.residuals)
    assert list.sort(certificate_residuals, string.compare)
      == certificate_residuals
    assert list.sort(expected_residuals, string.compare) == expected_residuals
    let assert [digest] = row.certificate.digests
    assert digest.projection == "evidence"
  })
}

fn digests_equal_independent_recomputation_except_intended_corruptions() {
  list.each(corpus.rows(), fn(row) {
    let assert [digest] = row.certificate.digests
    let independent =
      corpus.sha256_hex(
        bit_array.from_string(json_string.string_literal(
          row.certificate.evidence,
        )),
      )
    let intended =
      row.name == "digest" || row.name == "source_with_later_stages"
    let matches = digest.digest == independent
    assert matches == !intended
  })
}

fn table_order_does_not_change_outcomes() {
  let rows = corpus.rows()
  let reference = projection_with(corpus.table(), rows)
  let other = fn(_source, _coordinate, _observations, _evidence) {
    [ProjectionDigest("evidence", "0", CrossLanguage("other"))]
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
    let rows = corpus.rows()
    let texts =
      list.map2(rows, outcomes_with(table, rows), fn(row, outcome) {
        outcome_text(row, outcome)
      })
    assert "[" <> string.join(texts, ",") <> "]" == reference
  })
}

fn constructed_table_keeps_its_rules() {
  let assert Ok(first) =
    rule_table.new([#(corpus.revision, corpus.comparison_rule)])
  let other = fn(_source, _coordinate, _observations, _evidence) {
    [ProjectionDigest("evidence", "0", CrossLanguage("other"))]
  }
  let assert Ok(_) = rule_table.new([#(corpus.revision, other)])
  let rows = corpus.rows()
  assert projection_with(first, rows) == projection_with(corpus.table(), rows)
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
