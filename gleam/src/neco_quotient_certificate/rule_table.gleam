import gleam/list
import gleam/set.{type Set}
import neco_quotient_certificate/digest.{type ProjectionDigests}
import neco_quotient_certificate/source.{type SourceRef}

pub type Rule(s, rev, c, obs, e) =
  fn(SourceRef(s, rev), c, obs, e) -> ProjectionDigests

pub opaque type RuleTable(s, rev, c, obs, e) {
  RuleTable(entries: List(#(String, Rule(s, rev, c, obs, e))))
}

pub type DuplicateRule {
  DuplicateRule(rule_revision: String)
}

pub fn new(
  entries: List(#(String, Rule(s, rev, c, obs, e))),
) -> Result(RuleTable(s, rev, c, obs, e), DuplicateRule) {
  case first_duplicate(entries, set.new()) {
    Ok(Nil) -> Ok(RuleTable(entries))
    Error(duplicate) -> Error(duplicate)
  }
}

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
