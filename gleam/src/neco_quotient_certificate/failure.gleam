import gleam/string

/// 不一致を報告する照合の段階。
pub type Stage {
  Decode
  Source
  Coordinate
  Observations
  Digest
  Residual
}

/// 段階の表示名。
pub fn stage_name(stage: Stage) -> String {
  case stage {
    Decode -> "decode"
    Source -> "source"
    Coordinate -> "coordinate"
    Observations -> "observations"
    Digest -> "digest"
    Residual -> "residual"
  }
}

/// 不一致の対象となる証明書のリビジョンと入力の表示。
pub type Origin {
  Origin(
    rule_revision: String,
    source_identity: String,
    source_revision: String,
  )
}

/// 照合の失敗。provenance は呼び出す側の値をそのまま保持する。
pub type Mismatch(p) {
  Mismatch(
    operation: String,
    stage: Stage,
    expected: String,
    actual: String,
    origin: Origin,
    provenance: p,
    contributing: List(Mismatch(p)),
  )
}

/// 失敗の表示。操作、段階、期待値、実際の値、規則のリビジョン、入力を一文にする。
pub fn describe(mismatch: Mismatch(p)) -> String {
  string.concat([
    mismatch.operation,
    " failed at stage ",
    stage_name(mismatch.stage),
    ": expected ",
    mismatch.expected,
    ", actual ",
    mismatch.actual,
    " (rule ",
    mismatch.origin.rule_revision,
    ", source ",
    mismatch.origin.source_identity,
    "@",
    mismatch.origin.source_revision,
    ")",
  ])
}
