# 五言語の対応

証明書の照合には、五つの言語で共通の規約を定めています。各実装は同じ型と条件の前提を持ち、その結果は共通の試験データを用いて Lean の結果と比べます。

## 各言語の文書

| 言語 | 文書 |
|---|---|
| Rust | [`neco-quotient-certificate`](../rust/neco-quotient-certificate/README.md) |
| TypeScript | [`typescript`](../typescript/README.md) |
| Java | [`java`](../java/README.md) |
| Python | [`python`](../python/README.md) |
| Gleam | [`gleam`](../gleam/README.md) |

## 詳細

- 照合の条件と JSON 形式: [証明書](certificate.md)
- 型と照合の条件の言語間の対応: [言語間の型対応](type-correspondence.md)
- 比較事例と Lean の結果の再生成: [`comparison/certificate-admit`](../comparison/certificate-admit/README.md)
