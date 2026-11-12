import gleam/bit_array
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import json_string
import neco_quotient_certificate/certificate.{
  type Certificate, type Expected, Certificate, Expected, residual_set,
}
import neco_quotient_certificate/digest.{
  type DigestScope, type ProjectionDigest, type ProjectionDigests, CrossLanguage,
  ProjectionDigest, WithinRuntime,
}
import neco_quotient_certificate/rule_table.{type RuleTable}
import neco_quotient_certificate/source.{type SourceRef, SourceRef}

pub const revision = "comparison/sha256@1"

pub type Cert =
  Certificate(String, String, String, String, String, String)

pub type Exp =
  Expected(String, String, String, String, String)

pub type Row {
  Row(name: String, provenance: String, certificate: Cert, expected: Exp)
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(BitArray, Dynamic)

@external(erlang, "json", "decode")
fn json_decode(bytes: BitArray) -> Dynamic

@external(erlang, "neco_quotient_test_ffi", "sha256_hex")
pub fn sha256_hex(bytes: BitArray) -> String

pub fn parse_json(bytes: BitArray) -> Dynamic {
  json_decode(bytes)
}

pub fn read_bytes(name: String) -> BitArray {
  let assert Ok(bytes) = read_file("../comparison/certificate-admit/" <> name)
  bytes
}

pub fn rows() -> List(Row) {
  rows_from("cases.json")
}

pub fn rows_from(name: String) -> List(Row) {
  let assert Ok(rows) =
    decode.run(json_decode(read_bytes(name)), decode.list(row_decoder()))
  rows
}

pub fn table() -> RuleTable(String, String, String, String, String) {
  let assert Ok(table) = rule_table.new([#(revision, comparison_rule)])
  table
}

pub fn comparison_rule(
  _source: SourceRef(String, String),
  _coordinate: String,
  _observations: String,
  evidence: String,
) -> ProjectionDigests {
  [
    #(
      "evidence",
      ProjectionDigest(
        digest: sha256_hex(
          bit_array.from_string(json_string.string_literal(evidence)),
        ),
        scope: CrossLanguage("sha256"),
      ),
    ),
  ]
  |> dict.from_list
}

fn row_decoder() -> decode.Decoder(Row) {
  use name <- decode.field("name", decode.string)
  use provenance <- decode.field("provenance", decode.string)
  use certificate <- decode.field("certificate", certificate_decoder())
  use expected <- decode.field("expected", expected_decoder())
  decode.success(Row(name:, provenance:, certificate:, expected:))
}

fn certificate_decoder() -> decode.Decoder(Cert) {
  use rule_revision <- decode.field("rule_revision", decode.string)
  use source <- decode.field("source", source_decoder())
  use coordinate <- decode.field("coordinate", decode.string)
  use digests <- decode.field(
    "digests",
    decode.dict(decode.string, digest_decoder()),
  )
  use residuals <- decode.field("residuals", decode.list(decode.string))
  use observations <- decode.field("observations", decode.string)
  use evidence <- decode.field("evidence", decode.string)
  decode.success(Certificate(
    rule_revision:,
    source:,
    coordinate:,
    digests:,
    residuals: residual_set(residuals),
    observations:,
    evidence:,
  ))
}

fn expected_decoder() -> decode.Decoder(Exp) {
  use rule_revision <- decode.field("rule_revision", decode.string)
  use source <- decode.field("source", source_decoder())
  use coordinate <- decode.field("coordinate", decode.string)
  use observations <- decode.field("observations", decode.string)
  use residuals <- decode.field("residuals", decode.list(decode.string))
  decode.success(Expected(
    rule_revision:,
    source:,
    coordinate:,
    observations:,
    residuals: residual_set(residuals),
  ))
}

fn source_decoder() -> decode.Decoder(SourceRef(String, String)) {
  use identity <- decode.field("identity", decode.string)
  use revision <- decode.field("revision", decode.string)
  decode.success(SourceRef(identity:, revision:))
}

fn digest_decoder() -> decode.Decoder(ProjectionDigest) {
  use digest <- decode.field("digest", decode.string)
  use scope <- decode.field("scope", scope_decoder())
  decode.success(ProjectionDigest(digest:, scope:))
}

fn scope_decoder() -> decode.Decoder(DigestScope) {
  decode.one_of(
    {
      use payload <- decode.field("within_runtime", decode.string)
      decode.success(WithinRuntime(payload))
    },
    [
      {
        use payload <- decode.field("cross_language", decode.string)
        decode.success(CrossLanguage(payload))
      },
    ],
  )
}
