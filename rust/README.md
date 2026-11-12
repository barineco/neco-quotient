# Rust workspace

neco-quotient の Rust 実装です。

## crate の選択

| 目的 | crate |
|---|---|
| 証明書を照合する | [neco-quotient-certificate](neco-quotient-certificate) |
| データの保持の要否を判定する | [neco-quotient-retention](neco-quotient-retention) |
| 証明書を JSON へ符号化する | [neco-quotient-encoding](neco-quotient-encoding) |

各 crate は単独で利用できます。

## 内部用 crate

| crate | 用途 |
|---|---|
| neco-quotient-comparison-tests | 五言語間の照合結果を比較する検査 |

## ビルドと検査

```bash
cargo build --workspace
cargo test --workspace
```

## 概念と契約

証明書の欄、照合の条件、保持判定の入力と結果は [docs/](../docs) に記載されています。
