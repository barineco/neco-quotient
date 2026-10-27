# neco-quotient

用途に応じた識別と同一視を扱う基盤です。同一視できる範囲を証明書として記録し、計算結果の再利用や、再構成可能なデータの実体化解除に活用できます。

| 用途 | 実装 |
|---|---|
| 証明書を照合する | [rust/neco-quotient-certificate](rust/neco-quotient-certificate) |
| 実体化解除を判定する | [rust/neco-quotient-retention](rust/neco-quotient-retention) |
| 証明書を JSON へ符号化する | [rust/neco-quotient-encoding](rust/neco-quotient-encoding) |
| 定義と定理を検証する | [lean/](lean) |

## 詳細文書

- [観測関数族と商](docs/concepts.md): 観測尺度との関係と保証する性質
- [証明書](docs/certificate.md): 構造、照合、JSON 形式
- [保持の判定](docs/retention.md): 実体を保つか復元に委ねるかの判断
- [Lean の定義と定理](docs/lean.md): 定理が保証する範囲
- [五言語の対応](docs/languages.md): 各実装に共通する規約

## 検証

```bash
(cd lean && lake build)
(cd rust && cargo test --workspace)
```

## ライセンス

MIT License
