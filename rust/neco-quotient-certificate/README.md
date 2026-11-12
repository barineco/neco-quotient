# neco-quotient-certificate

証明書を期待値と照合する crate です。

照合の条件は [docs/certificate.md](../../docs/certificate.md) に記載されています。

## 導入

リポジトリを git の依存として指定します。Rust 1.82 以降で動作し、標準ライブラリのみを使います。

```toml
[dependencies]
neco-quotient-certificate = { git = "https://github.com/barineco/neco-quotient.git" }
```

## 使用例

`RuleTable` を作り、証明書を期待値と照合する例:

```rust
use neco_quotient_certificate::{
    admit, Certificate, DigestScope, Expected, ProjectionDigest, ProjectionDigests, ResidualSet,
    Rule, RuleTable, SourceRef,
};

#[derive(Debug, Clone, PartialEq, Eq)]
enum Observation {
    Graph,
    Metadata,
}

struct DemoRule;

impl Rule<String, u64, u32, Vec<Observation>, u32> for DemoRule {
    fn recompute(
        &self,
        source: &SourceRef<String, u64>,
        coordinate: &u32,
        observations: &Vec<Observation>,
        evidence: &u32,
    ) -> ProjectionDigests {
        observations
            .iter()
            .map(|observation| {
                let projection = match observation {
                    Observation::Graph => "graph",
                    Observation::Metadata => "metadata",
                };
                let digest = ProjectionDigest {
                    digest: format!(
                        "{}@{}:{}:{}",
                        source.identity, source.revision, coordinate, evidence
                    ),
                    scope: DigestScope::WithinRuntime("demo-observation@1".to_string()),
                };
                (projection.to_string(), digest)
            })
            .collect()
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let table = RuleTable::new(vec![(
        "demo@1".to_string(),
        Box::new(DemoRule)
            as Box<dyn Rule<String, u64, u32, Vec<Observation>, u32> + Send + Sync>,
    )])?;
    let source = SourceRef {
        identity: "body".to_string(),
        revision: 7u64,
    };
    let observations = vec![Observation::Graph, Observation::Metadata];
    let certificate = Certificate {
        rule_revision: "demo@1".to_string(),
        source: source.clone(),
        coordinate: 1u32,
        digests: DemoRule.recompute(&source, &1, &observations, &5),
        residuals: ResidualSet::<String>::new([]),
        observations: observations.clone(),
        evidence: 5u32,
    };
    let expected = Expected {
        rule_revision: "demo@1".to_string(),
        source,
        coordinate: 1u32,
        observations,
        residuals: ResidualSet::<String>::new([]),
    };

    let checked = admit(&table, certificate, expected, "caller provenance")?;
    assert_eq!(checked.recomputed().len(), 2);
    Ok(())
}
```

`Observation` の各値は一つの射影を選び、その列が同一視に用いる観測になります。

## 主な API

- `RuleTable::new`: 規則の表を作る。同じリビジョンが重複すると `DuplicateRule` を返す
- `admit`: 証明書を期待値と照合し、`Result<Checked, Mismatch>` を返す
- `Rule`: 射影ダイジェストを再計算する規則のトレイト
- `VerifiedRefinement`: 精密化の前後の評価を、共通の入力参照に結び付ける

型の言語間の対応は [docs/type-correspondence.md](../../docs/type-correspondence.md) にあります。照合の定理は Lean の `Certificate` モジュールが証明し、この実装との対応は手動で確認しています。

## 検査

```sh
cd rust
cargo test -p neco-quotient-certificate
```

## ライセンス

MIT
