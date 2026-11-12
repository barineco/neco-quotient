import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/string
import json_string.{string_literal}
import neco_quotient_certificate/certificate.{residual_set, residual_values}
import neco_quotient_certificate/refinement.{
  type RefinementOutcome, Residual, Resolved, Stopped, same_outcome,
}

type Outcome =
  RefinementOutcome(String, String, String)

type Row {
  Row(name: String, left: Outcome, right: Outcome)
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(BitArray, Dynamic)

@external(erlang, "json", "decode")
fn json_decode(bytes: BitArray) -> Dynamic

pub fn run() {
  outcomes_match_lean_outcomes()
  swapped_and_reordered_inputs_are_separated()
}

fn read_text(name: String) -> String {
  let assert Ok(bytes) = read_file("../comparison/refinement-outcome/" <> name)
  let assert Ok(text) = bit_array.to_string(bytes)
  text
}

fn outcome_decoder() -> decode.Decoder(Outcome) {
  use kind <- decode.field("kind", decode.string)
  use value <- decode.field("value", decode.string)
  case kind {
    "resolved" -> decode.success(Resolved(value))
    "residual" -> {
      use residuals <- decode.field("residuals", decode.list(decode.string))
      decode.success(Residual(value, residual_set(residuals)))
    }
    _ -> {
      use residuals <- decode.field("residuals", decode.list(decode.string))
      use cause <- decode.field("cause", decode.string)
      decode.success(Stopped(value, residual_set(residuals), cause))
    }
  }
}

fn row_decoder() -> decode.Decoder(Row) {
  use name <- decode.field("name", decode.string)
  use left <- decode.field("left", outcome_decoder())
  use right <- decode.field("right", outcome_decoder())
  decode.success(Row(name, left, right))
}

fn rows() -> List(Row) {
  let assert Ok(rows) =
    decode.run(
      json_decode(bit_array.from_string(read_text("cases.json"))),
      decode.list(row_decoder()),
    )
  rows
}

fn array(items: List(String)) -> String {
  "[" <> string.join(items, ",") <> "]"
}

fn sorted_residuals(values: List(String)) -> String {
  values
  |> list.sort(string.compare)
  |> list.map(string_literal)
  |> array
}

fn outcome_text(outcome: Outcome) -> String {
  case outcome {
    Resolved(value) ->
      "{\"kind\":\"resolved\",\"value\":" <> string_literal(value) <> "}"
    Residual(value, residuals) ->
      "{\"kind\":\"residual\",\"residuals\":"
      <> sorted_residuals(residual_values(residuals))
      <> ",\"value\":"
      <> string_literal(value)
      <> "}"
    Stopped(value, residuals, cause) ->
      "{\"cause\":"
      <> string_literal(cause)
      <> ",\"kind\":\"stopped\",\"residuals\":"
      <> sorted_residuals(residual_values(residuals))
      <> ",\"value\":"
      <> string_literal(value)
      <> "}"
  }
}

fn bool_text(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn row_text(row: Row) -> String {
  "{\"left\":"
  <> outcome_text(row.left)
  <> ",\"name\":"
  <> string_literal(row.name)
  <> ",\"right\":"
  <> outcome_text(row.right)
  <> ",\"same\":"
  <> bool_text(same_outcome(row.left, row.right))
  <> "}"
}

fn outcomes_match_lean_outcomes() {
  let rows = rows()
  assert array(list.map(rows, row_text)) == read_text("lean-outcomes.json")
  let names = list.map(rows, fn(row) { row.name })
  assert list.length(list.unique(names)) == list.length(names)
  assert list.any(rows, fn(row) { same_outcome(row.left, row.right) })
  assert list.any(rows, fn(row) { !same_outcome(row.left, row.right) })
}

fn swapped_and_reordered_inputs_are_separated() {
  let rows = rows()
  list.each(
    ["residual_order_and_duplicates", "stopped_order_and_duplicates"],
    fn(name) {
      let assert Ok(row) = list.find(rows, fn(row) { row.name == name })
      assert same_outcome(row.left, row.right)
    },
  )
  list.each(
    ["case_resolved_residual", "case_residual_stopped", "case_resolved_stopped"],
    fn(name) {
      let assert Ok(row) = list.find(rows, fn(row) { row.name == name })
      assert !same_outcome(row.left, row.right)
    },
  )
  assert list.any(rows, fn(row) {
    { row.left == row.right } != same_outcome(row.left, row.right)
  })
}
