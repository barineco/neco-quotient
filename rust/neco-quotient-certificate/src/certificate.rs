use std::collections::BTreeMap;

#[derive(Debug, Clone)]
pub struct ResidualSet<T> {
    values: Vec<T>,
}

impl<T: Eq> ResidualSet<T> {
    pub fn new(values: impl IntoIterator<Item = T>) -> Self {
        let mut unique = Vec::new();
        for value in values {
            if !unique.contains(&value) {
                unique.push(value);
            }
        }
        Self { values: unique }
    }

    pub fn iter(&self) -> impl Iterator<Item = &T> {
        self.values.iter()
    }

    pub fn len(&self) -> usize {
        self.values.len()
    }

    pub fn is_empty(&self) -> bool {
        self.values.is_empty()
    }

    pub fn contains(&self, value: &T) -> bool {
        self.values.contains(value)
    }
}

impl<T: PartialEq> PartialEq for ResidualSet<T> {
    fn eq(&self, other: &Self) -> bool {
        self.values.len() == other.values.len()
            && self
                .values
                .iter()
                .all(|value| other.values.iter().any(|item| item == value))
    }
}

impl<T: Eq> Eq for ResidualSet<T> {}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceRef<S, Rev> {
    pub identity: S,
    pub revision: Rev,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DigestScope {
    WithinRuntime(String),
    CrossLanguage(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProjectionDigest {
    pub digest: String,
    pub scope: DigestScope,
}

pub type ProjectionDigests = BTreeMap<String, ProjectionDigest>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Certificate<S, Rev, C, Obs, R, E> {
    pub rule_revision: String,
    pub source: SourceRef<S, Rev>,
    pub coordinate: C,
    pub digests: ProjectionDigests,
    pub residuals: ResidualSet<R>,
    pub observations: Obs,
    pub evidence: E,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Expected<S, Rev, C, Obs, R> {
    pub rule_revision: String,
    pub source: SourceRef<S, Rev>,
    pub coordinate: C,
    pub observations: Obs,
    pub residuals: ResidualSet<R>,
}
