# neco-quotient

用途に応じた識別と同一視を扱う基盤です。計算結果の再利用や、再構成可能なデータの保持管理に活用できます。

| 用途 | 実装 |
|---|---|
| 証明書の照合 | [rust/neco-quotient-certificate](rust/neco-quotient-certificate) |
| データの保持の要否判定 | [rust/neco-quotient-retention](rust/neco-quotient-retention) |
| 証明書の通信形式の正規化と復号 | [rust/neco-quotient-encoding](rust/neco-quotient-encoding) |
| 定義と定理の検証 | [lean/](lean) |

## 詳細文書

- [観測関数族と商](docs/concepts.md): 観測尺度との関係と保証する性質
- [証明書](docs/certificate.md): 構造、照合、JSON 形式
- [保持の判定](docs/retention.md): 保持の要否を決める条件、判定の入力と結果
- [Lean の定義と定理](docs/lean.md): 定理が保証する範囲
- [五言語の対応](docs/languages.md): 各実装に共通する規約

## 検証

```bash
(cd lean && lake build)
(cd rust && cargo test --workspace)
```

## ライセンス

MIT License
