use std::fmt;

/// 不一致を報告する照合の段階。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Stage {
    Decode,
    Source,
    Coordinate,
    Observations,
    Digest,
    Residual,
}

impl fmt::Display for Stage {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            Stage::Decode => "decode",
            Stage::Source => "source",
            Stage::Coordinate => "coordinate",
            Stage::Observations => "observations",
            Stage::Digest => "digest",
            Stage::Residual => "residual",
        };
        f.write_str(name)
    }
}

/// 不一致の対象となる証明書のリビジョンと入力。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Origin {
    pub rule_revision: String,
    pub source_identity: String,
    pub source_revision: String,
}

/// 照合の失敗。
///
/// Rust の比較は全欄で行う。言語間の同一性は操作、段階、出所で比べ、期待値と実際の値は診断に限る。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Mismatch<P> {
    pub operation: &'static str,
    pub stage: Stage,
    pub expected: String,
    pub actual: String,
    pub origin: Origin,
    pub provenance: P,
    pub contributing: Vec<Mismatch<P>>,
}

impl<P> fmt::Display for Mismatch<P> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{} failed at stage {}: expected {}, actual {} (rule {}, source {}@{})",
            self.operation,
            self.stage,
            self.expected,
            self.actual,
            self.origin.rule_revision,
            self.origin.source_identity,
            self.origin.source_revision,
        )
    }
}

impl<P: fmt::Debug> std::error::Error for Mismatch<P> {}

#[cfg(test)]
mod tests {
    use super::{Mismatch, Origin, Stage};

    fn sample(provenance: &'static str) -> Mismatch<&'static str> {
        Mismatch {
            operation: "admit",
            stage: Stage::Digest,
            expected: "a".into(),
            actual: "b".into(),
            origin: Origin {
                rule_revision: "rule@1".into(),
                source_identity: "src".into(),
                source_revision: "7".into(),
            },
            provenance,
            contributing: Vec::new(),
        }
    }

    #[test]
    fn equality_compares_every_field() {
        let base = sample("caller");
        assert_eq!(base, base.clone());
        assert_ne!(base, sample("other"));

        let mut with_contributing = sample("caller");
        with_contributing.contributing.push(sample("caller"));
        assert_ne!(base, with_contributing);
    }

    #[test]
    fn mismatch_is_an_error_when_its_provenance_is_debug() {
        fn assert_error<E: std::error::Error>(_: &E) {}
        assert_error(&sample("caller"));
    }
}
