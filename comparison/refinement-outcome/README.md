# 精密化の判定の状態の共通の比較

このディレクトリでは、精密化の判定の状態 ( Lean の `RefinementStatus`、他の言語の `RefinementOutcome` ) の等しさを比べるための共通の事例を扱います。同じ事例を各言語に渡し、左右の判定の状態を等しいとするかどうかが Lean の結果と一致することを確かめます。

## ファイル

| ファイル | 内容 |
|---|---|
| `cases.json` | 事例。名前と、比べる左右の判定の状態を持つ |
| `lean-outcomes.json` | 各事例に Lean の比較を適用した結果。事例に等しさの結果 `same` を加える |

## 判定の状態の等しさ

二つの判定の状態は、場合と値が等しく、残余集合の要素の所属が一致し、停止の場合は原因も等しいときに等しいとします。残余集合は要素の所属で比べ、順序と重複は比べる対象から外します。

## 事例

| 名前の接頭辞 | 比べる内容 |
|---|---|
| `resolved_` | 確定どうしの値 |
| `residual_` | 残余どうしの値、残余集合の順序と重複、要素の所属 |
| `stopped_` | 停止どうしの値、残余集合、原因 |
| `case_` | 異なる場合どうし。空の残余集合を持つ残余や停止と、確定との取り違えを含む |

## Lean の結果の再生成

Lean の結果を作り直すには、`lean` ディレクトリで次のコマンドを実行します。

```bash
lake build
lake exe refinement_compare ../comparison/refinement-outcome/cases.json ../comparison/refinement-outcome/lean-outcomes.json
```

Rust の結合テスト `comparison_refinement` は、このディレクトリの事例と Lean の結果を読み、比較の結果を突き合わせます。各言語の検査の実行方法は、各言語の README を参照してください。
