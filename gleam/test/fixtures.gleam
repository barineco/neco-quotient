import gleam/dict
import gleam/int
import gleam/list
import gleam/string
import neco_quotient_certificate/certificate.{
  type Certificate, type Expected, Certificate, Expected, residual_set,
}
import neco_quotient_certificate/digest.{
  type ProjectionDigests, CrossLanguage, ProjectionDigest,
}
import neco_quotient_certificate/rule_table.{type Rule, type RuleTable}
import neco_quotient_certificate/source.{type SourceRef, SourceRef}

pub const revision = "rule@1"

pub const coordinate = 1

pub const observations = 3

pub const evidence = 5

pub const residuals = [2]

pub type Fixture =
  Certificate(String, Int, Int, Int, Int, Int)

pub type FixtureExpected =
  Expected(String, Int, Int, Int, Int)

pub fn semantics(salt: String) -> Rule(String, Int, Int, Int, Int) {
  fn(
    src: SourceRef(String, Int),
    coordinate: Int,
    observations: Int,
    evidence: Int,
  ) {
    list.map(["graph", "metadata"], fn(projection) {
      let digest =
        string.join(
          [
            salt,
            projection,
            src.identity,
            int.to_string(src.revision),
            int.to_string(coordinate),
            int.to_string(observations),
            int.to_string(evidence),
          ],
          "|",
        )
      #(
        projection,
        ProjectionDigest(digest:, scope: CrossLanguage("fixture@1")),
      )
    })
    |> dict.from_list
  }
}

pub fn source() -> SourceRef(String, Int) {
  SourceRef(identity: "src", revision: 7)
}

pub fn digests() -> ProjectionDigests {
  semantics("default")(source(), coordinate, observations, evidence)
}

pub fn certificate() -> Fixture {
  Certificate(
    rule_revision: revision,
    source: source(),
    coordinate:,
    digests: digests(),
    residuals: residual_set(residuals),
    observations:,
    evidence:,
  )
}

pub fn expected() -> FixtureExpected {
  Expected(
    rule_revision: revision,
    source: source(),
    coordinate:,
    observations:,
    residuals: residual_set(residuals),
  )
}

pub fn table() -> RuleTable(String, Int, Int, Int, Int) {
  table_with("default")
}

pub fn table_with(salt: String) -> RuleTable(String, Int, Int, Int, Int) {
  let assert Ok(table) = rule_table.new([#(revision, semantics(salt))])
  table
}

pub fn break_decode(cert: Fixture) -> Fixture {
  Certificate(..cert, rule_revision: "rule@2")
}

pub fn break_source(cert: Fixture) -> Fixture {
  Certificate(..cert, source: SourceRef(identity: "src", revision: 8))
}

pub fn break_coordinate(cert: Fixture) -> Fixture {
  Certificate(..cert, coordinate: 9)
}

pub fn break_observations(cert: Fixture) -> Fixture {
  Certificate(..cert, observations: 9)
}

pub fn break_digest(cert: Fixture) -> Fixture {
  Certificate(
    ..cert,
    digests: semantics("other")(
      cert.source,
      cert.coordinate,
      cert.observations,
      cert.evidence,
    ),
  )
}

pub fn break_residual(cert: Fixture) -> Fixture {
  Certificate(..cert, residuals: residual_set([9]))
}
