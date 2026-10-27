import gleam/list
import gleam/set.{type Set}
import neco_quotient_certificate/digest.{type ProjectionDigest}
import neco_quotient_certificate/source.{type SourceRef}

/// 座標、観測、証拠から入力の射影ダイジェストを再計算する関数。
/// 返す射影ダイジェストの列は射影の昇順に並べる。
pub type Rule(s, rev, c, obs, e) =
  fn(SourceRef(s, rev), c, obs, e) -> List(ProjectionDigest)

/// 規則のリビジョンをキーとする規則の表。リビジョンは構築時に一意であることを検査する。
pub opaque type RuleTable(s, rev, c, obs, e) {
  RuleTable(entries: List(#(String, Rule(s, rev, c, obs, e))))
}

/// 表の中で二度以上現れる規則のリビジョン。
pub type DuplicateRule {
  DuplicateRule(rule_revision: String)
}

/// 規則のリビジョンと規則の組の列から表を構築する。二度目に現れた最初のリビジョンを DuplicateRule で拒否する。
pub fn new(
  entries: List(#(String, Rule(s, rev, c, obs, e))),
) -> Result(RuleTable(s, rev, c, obs, e), DuplicateRule) {
  case first_duplicate(entries, set.new()) {
    Ok(Nil) -> Ok(RuleTable(entries))
    Error(duplicate) -> Error(duplicate)
  }
}

/// リビジョンに対応する規則を探す。
pub fn lookup(
  table: RuleTable(s, rev, c, obs, e),
  rule_revision: String,
) -> Result(Rule(s, rev, c, obs, e), Nil) {
  list.key_find(table.entries, rule_revision)
}

fn first_duplicate(
  entries: List(#(String, Rule(s, rev, c, obs, e))),
  seen: Set(String),
) -> Result(Nil, DuplicateRule) {
  case entries {
    [] -> Ok(Nil)
    [#(rule_revision, _), ..rest] ->
      case set.contains(seen, rule_revision) {
        True -> Error(DuplicateRule(rule_revision))
        False -> first_duplicate(rest, set.insert(seen, rule_revision))
      }
  }
}
