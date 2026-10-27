/// 残余の要素所属で同一性を決める集合。
#[derive(Debug, Clone)]
pub struct ResidualSet<T> {
    values: Vec<T>,
}

impl<T: Eq> ResidualSet<T> {
    /// 入力の順序を残し、重複を除いた残余集合を作る。
    pub fn new(values: impl IntoIterator<Item = T>) -> Self {
        let mut unique = Vec::new();
        for value in values {
            if !unique.contains(&value) {
                unique.push(value);
            }
        }
        Self { values: unique }
    }

    /// 集合の要素を構築時の順で読む。
    pub fn iter(&self) -> impl Iterator<Item = &T> {
        self.values.iter()
    }

    /// 集合の要素数を返す。
    pub fn len(&self) -> usize {
        self.values.len()
    }

    /// 集合が空か返す。
    pub fn is_empty(&self) -> bool {
        self.values.is_empty()
    }

    /// 集合が指定要素を含むか返す。
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

/// 証明書が記述する入力の識別子とリビジョン。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceRef<S, Rev> {
    pub identity: S,
    pub revision: Rev,
}

/// 射影ダイジェストを比べられる範囲。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DigestScope {
    WithinRuntime(String),
    CrossLanguage(String),
}

/// 入力の一つの射影ダイジェスト。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProjectionDigest {
    pub projection: String,
    pub digest: String,
    pub scope: DigestScope,
}

/// 照合に提出する証明書。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Certificate<S, Rev, C, Obs, R, E> {
    pub rule_revision: String,
    pub source: SourceRef<S, Rev>,
    pub coordinate: C,
    pub digests: Vec<ProjectionDigest>,
    pub residuals: ResidualSet<R>,
    pub observations: Obs,
    pub evidence: E,
}

/// 証明書を照合する期待値。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Expected<S, Rev, C, Obs, R> {
    pub rule_revision: String,
    pub source: SourceRef<S, Rev>,
    pub coordinate: C,
    pub observations: Obs,
    pub residuals: ResidualSet<R>,
}
