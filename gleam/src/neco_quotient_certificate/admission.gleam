import gleam/result
import gleam/string
import neco_quotient_certificate/certificate.{
  type Certificate, type Expected, residual_values, same_residuals,
}
import neco_quotient_certificate/digest.{type ProjectionDigest}
import neco_quotient_certificate/failure.{
  type Mismatch, type Stage, Coordinate, Decode, Digest, Mismatch, Observations,
  Origin, Residual, Source,
}
import neco_quotient_certificate/rule_table.{type RuleTable}
import neco_quotient_certificate/source.{type SourceRef}

const operation = "admit"

const table_expectation = "rule in table"

/// 照合を通過した証明書。構築はこのモジュールの admit に限る。
pub opaque type Checked(s, rev, c, obs, r, e) {
  Checked(
    RuleTable(s, rev, c, obs, e),
    Certificate(s, rev, c, obs, r, e),
    List(ProjectionDigest),
  )
}

/// 照合を通過した証明書を返す。
pub fn certificate(
  checked: Checked(s, rev, c, obs, r, e),
) -> Certificate(s, rev, c, obs, r, e) {
  let Checked(_, certificate, _) = checked
  certificate
}

/// 照合を通過した証明書の出所を返す。
pub fn source(checked: Checked(s, rev, c, obs, r, e)) -> SourceRef(s, rev) {
  let Checked(_, certificate, _) = checked
  certificate.source
}

/// 表の規則が再計算した射影ダイジェストの列を返す。
pub fn recomputed(
  checked: Checked(s, rev, c, obs, r, e),
) -> List(ProjectionDigest) {
  let Checked(_, _, recomputed) = checked
  recomputed
}

/// 証明書を期待値と照合する。段階はリビジョン、表、入力参照、座標、観測、射影ダイジェスト、残余の順に検査し、
/// 最初に不一致となった段階の失敗を返す。失敗の origin は証明書のリビジョンと入力参照から作り、
/// provenance は呼び出す側の値をそのまま保持する。show_identity と show_revision は失敗の表示に使う。
pub fn admit(
  table: RuleTable(s, rev, c, obs, e),
  certificate: Certificate(s, rev, c, obs, r, e),
  expected: Expected(s, rev, c, obs, r),
  provenance: p,
  show_identity: fn(s) -> String,
  show_revision: fn(rev) -> String,
) -> Result(Checked(s, rev, c, obs, r, e), Mismatch(p)) {
  let mismatch = fn(stage: Stage, expected_text: String, actual_text: String) {
    Mismatch(
      operation: operation,
      stage: stage,
      expected: expected_text,
      actual: actual_text,
      origin: Origin(
        rule_revision: certificate.rule_revision,
        source_identity: show_identity(certificate.source.identity),
        source_revision: show_revision(certificate.source.revision),
      ),
      provenance: provenance,
      contributing: [],
    )
  }
  let ensure = fn(
    stage: Stage,
    equal: Bool,
    expected_text: fn() -> String,
    actual_text: fn() -> String,
  ) -> Result(Nil, Mismatch(p)) {
    case equal {
      True -> Ok(Nil)
      False -> Error(mismatch(stage, expected_text(), actual_text()))
    }
  }

  use _ <- result.try(
    ensure(
      Decode,
      certificate.rule_revision == expected.rule_revision,
      fn() { expected.rule_revision },
      fn() { certificate.rule_revision },
    ),
  )
  use rule <- result.try(
    case rule_table.lookup(table, certificate.rule_revision) {
      Ok(rule) -> Ok(rule)
      Error(Nil) ->
        Error(mismatch(Decode, table_expectation, certificate.rule_revision))
    },
  )
  use _ <- result.try(
    ensure(
      Source,
      certificate.source == expected.source,
      fn() {
        source_text(
          expected.source.identity,
          expected.source.revision,
          show_identity,
          show_revision,
        )
      },
      fn() {
        source_text(
          certificate.source.identity,
          certificate.source.revision,
          show_identity,
          show_revision,
        )
      },
    ),
  )
  use _ <- result.try(
    ensure(
      Coordinate,
      certificate.coordinate == expected.coordinate,
      fn() { string.inspect(expected.coordinate) },
      fn() { string.inspect(certificate.coordinate) },
    ),
  )
  use _ <- result.try(
    ensure(
      Observations,
      certificate.observations == expected.observations,
      fn() { string.inspect(expected.observations) },
      fn() { string.inspect(certificate.observations) },
    ),
  )
  let recomputed =
    rule(
      certificate.source,
      certificate.coordinate,
      certificate.observations,
      certificate.evidence,
    )
  use _ <- result.try(
    ensure(
      Digest,
      certificate.digests == recomputed,
      fn() { string.inspect(recomputed) },
      fn() { string.inspect(certificate.digests) },
    ),
  )
  use _ <- result.try(
    ensure(
      Residual,
      same_residuals(certificate.residuals, expected.residuals),
      fn() { string.inspect(residual_values(expected.residuals)) },
      fn() { string.inspect(residual_values(certificate.residuals)) },
    ),
  )
  Ok(Checked(table, certificate, recomputed))
}

fn source_text(
  identity: s,
  revision: rev,
  show_identity: fn(s) -> String,
  show_revision: fn(rev) -> String,
) -> String {
  show_identity(identity) <> "@" <> show_revision(revision)
}
