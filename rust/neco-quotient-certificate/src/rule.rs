use std::collections::BTreeSet;
use std::fmt;

use crate::certificate::{ProjectionDigest, SourceRef};

/// 座標、観測、証拠から入力の射影ダイジェストを再計算する。
/// 返す射影ダイジェストは射影の昇順に並べる。
pub trait Rule<S, Rev, C, Obs, E> {
    fn recompute(
        &self,
        source: &SourceRef<S, Rev>,
        coordinate: &C,
        observations: &Obs,
        evidence: &E,
    ) -> Vec<ProjectionDigest>;
}

/// 表が所有する規則。
pub type BoxedRule<S, Rev, C, Obs, E> = Box<dyn Rule<S, Rev, C, Obs, E> + Send + Sync>;

/// 規則のリビジョンと、そのリビジョンが指す規則の組。
pub type RuleEntry<S, Rev, C, Obs, E> = (String, BoxedRule<S, Rev, C, Obs, E>);

/// 規則のリビジョンをキーとする規則の表。
pub struct RuleTable<S, Rev, C, Obs, E> {
    entries: Vec<RuleEntry<S, Rev, C, Obs, E>>,
}

/// 表の中で二度以上現れる規則のリビジョン。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DuplicateRule {
    pub rule_revision: String,
}

impl fmt::Display for DuplicateRule {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "rule revision {} appears more than once",
            self.rule_revision
        )
    }
}

impl std::error::Error for DuplicateRule {}

impl<S, Rev, C, Obs, E> RuleTable<S, Rev, C, Obs, E> {
    /// 表を構築する。二度以上現れる最初の規則のリビジョンを拒否する。
    pub fn new(entries: Vec<RuleEntry<S, Rev, C, Obs, E>>) -> Result<Self, DuplicateRule> {
        let mut seen = BTreeSet::new();
        for (rule_revision, _) in &entries {
            if !seen.insert(rule_revision.as_str()) {
                return Err(DuplicateRule {
                    rule_revision: rule_revision.clone(),
                });
            }
        }
        Ok(Self { entries })
    }

    pub(crate) fn lookup(
        &self,
        rule_revision: &str,
    ) -> Option<&(dyn Rule<S, Rev, C, Obs, E> + Send + Sync)> {
        self.entries
            .iter()
            .find(|(revision, _)| revision.as_str() == rule_revision)
            .map(|(_, rule)| &**rule)
    }
}

#[cfg(test)]
mod tests {
    use super::{DuplicateRule, Rule, RuleEntry, RuleTable};
    use crate::certificate::{ProjectionDigest, SourceRef};

    struct Silent;

    impl Rule<String, u64, u32, u32, ()> for Silent {
        fn recompute(
            &self,
            _source: &SourceRef<String, u64>,
            _coordinate: &u32,
            _observations: &u32,
            _evidence: &(),
        ) -> Vec<ProjectionDigest> {
            Vec::new()
        }
    }

    fn entry(revision: &str) -> RuleEntry<String, u64, u32, u32, ()> {
        (revision.to_string(), Box::new(Silent))
    }

    #[test]
    fn table_with_distinct_revisions_is_built() {
        assert!(RuleTable::new(vec![entry("rule@1"), entry("rule@2")]).is_ok());
    }

    #[test]
    fn duplicate_revision_is_rejected_at_construction() {
        let result = RuleTable::new(vec![entry("rule@1"), entry("rule@2"), entry("rule@1")]);
        assert_eq!(
            result.err(),
            Some(DuplicateRule {
                rule_revision: "rule@1".into()
            })
        );
    }

    #[test]
    fn duplicate_rule_display_names_the_revision() {
        let error = DuplicateRule {
            rule_revision: "rule@1".into(),
        };
        assert_eq!(
            error.to_string(),
            "rule revision rule@1 appears more than once"
        );
    }
}
