import gleam/int
import gleam/list
import gleam/string
import neco_quotient_certificate/certificate.{
  type Certificate, type Expected, Certificate, Expected, residual_set,
}
import neco_quotient_certificate/digest.{
  type ProjectionDigest, CrossLanguage, ProjectionDigest,
}
import neco_quotient_certificate/failure.{
  type Stage, Coordinate, Decode, Digest, Observations, Residual, Source,
}
import neco_quotient_certificate/rule_table.{type Rule, type RuleTable}
import neco_quotient_certificate/source.{type SourceRef, SourceRef}

pub const revision = "rule@1"

pub const coordinate = 1

pub const observations = 3

pub const evidence = 5

pub const residuals = [2]

pub const stages = [Decode, Source, Coordinate, Observations, Digest, Residual]

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
      ProjectionDigest(
        projection:,
        digest: string.join(
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
        ),
        scope: CrossLanguage("fixture@1"),
      )
    })
  }
}

pub fn source() -> SourceRef(String, Int) {
  SourceRef(identity: "src", revision: 7)
}

pub fn digests() -> List(ProjectionDigest) {
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

pub fn break_stage(cert: Fixture, stage: Stage) -> Fixture {
  case stage {
    Decode -> Certificate(..cert, rule_revision: "rule@2")
    Source ->
      Certificate(..cert, source: SourceRef(identity: "src", revision: 8))
    Coordinate -> Certificate(..cert, coordinate: 9)
    Observations -> Certificate(..cert, observations: 9)
    Digest ->
      Certificate(
        ..cert,
        digests: semantics("other")(
          cert.source,
          cert.coordinate,
          cert.observations,
          cert.evidence,
        ),
      )
    Residual -> Certificate(..cert, residuals: residual_set([9]))
  }
}
