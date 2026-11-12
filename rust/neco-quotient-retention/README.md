# neco-quotient-retention

対象のデータを実体として保持すべきか、復元に委ねてよいかを判定する crate です。

## 公開 API

| 名前 | 役割 |
|---|---|
| `judge_erasure` | 宣言した利用、復元手段、観測から保持判定を返す |
| `ErasureRequest` | 判定対象、復元から除く観測、実体化解除の後も結果の取得を保つ観測を結び付ける |
| `LiveSet` | 対象に関係する利用と未完了の作用を表す |
| `Recoverability` | データの復元手段とその証拠を表す |
| `ErasureDecision` | 実体化解除、保持、入力不足のいずれかを返す |
| `DematerializeWitness` | 実体化解除の対象、復元手段、復元から除く観測を保持する |
| `RetentionReason` | 対象の実体を保持する条件を表す |

観測間の関係と各結果の成立条件は [docs/retention.md](../../docs/retention.md) を参照してください。

## 使用例

```rust
use neco_quotient_retention::{
    judge_erasure, ErasureDecision, ErasureRequest, LiveSet, MissingInput, Recoverability,
};

fn main() {
    let live = LiveSet {
        active_bases: vec!["basis-a"],
        branch_roots: vec![],
        future_uses: vec!["node-2"],
        outstanding_effects: vec![],
        outstanding_signals: vec![],
    };
    let request = ErasureRequest {
        target: "node-1",
        target_basis: Some("basis-b"),
        removed_observations: vec![],
        preserved_observations: vec!["obs-x"],
    };
    let recoverability: Option<Recoverability<&str, &str>> =
        Some(Recoverability::Source("source-ref"));

    match judge_erasure(request, &live, recoverability) {
        ErasureDecision::Dematerialize(witness) => {
            println!("実体化解除: {}", witness.target);
        }
        ErasureDecision::Retain(reasons) => {
            println!("保持: {} 件の理由", reasons.len());
        }
        ErasureDecision::Rejected(MissingInput::RecoverabilityUnknown) => {
            println!("復元手段が未確定");
        }
        ErasureDecision::Rejected(MissingInput::RemovedObservationsUndeclared) => {
            println!("除外する観測が未宣言");
        }
    }
}
```

この例の入力と結果は以下の値を取ります。

- 復元手段: 元の入力から `obs-x` の結果を復元する
- 復元から除く観測: 空の列
- 実体化解除の後も結果の取得を保つ観測: `obs-x`
- 保持理由: 0 件

この入力に対しては `Dematerialize` が返されます。

## Lean との対応

Lean の `Retention` モジュールが判定の必要十分性を証明します。実装との対応は手動で確認しています。

## ライセンス

MIT
