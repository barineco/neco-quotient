# Lean workspace

neco-quotient の定義と定理を検証する Lean 4 プロジェクトです。各モジュールが証明する性質は [Lean の定義と定理](../docs/lean.md) で説明します。

## 必要な環境

- Lean: `lean-toolchain` に記載のバージョン (v4.32.1)

`elan` を導入していれば、このディレクトリで `lake` を実行したときに記載のバージョンが選択されます。

## ビルドと検査

```bash
cd lean
lake build
```

`lake build` は全ての定理を型検査し、次の二つの検査も行います。

- `Axioms`: 公開する定理が標準の公理だけに依存すること
- `Guards`: 照合済みの値を作れるのは `admit` だけであること

## 他の Lean プロジェクトからの利用

利用する側の `lakefile.toml` にこのディレクトリを依存として追加し、`rev` には利用するコミットを指定します。

```toml
[[require]]
name = "NecoQuotient"
git = "https://github.com/barineco/neco-quotient.git"
rev = "<commit>"
subDir = "lean"
```

利用する側の Lean のバージョンは、`lean-toolchain` の記載と揃える必要があります。モジュールは個別に読み込むことも、`import NecoQuotient` で全てを読み込むことも可能です。

証明書と期待値を作って照合し、六つの一致条件から照合の成功を定理 `admit_complete` で導く例:

```lean
import NecoQuotient.Certificate

open NecoQuotient

def recompute (_ : SourceRef String String) (_ : String) (_ : String) (evidence : String) :
    List ProjectionDigest :=
  [{ projection := "evidence", digest := evidence, scope := .crossLanguage "example" }]

def certificate : Certificate String String String String String String where
  ruleRevision := "example@1"
  source := { identity := "doc-1", revision := "3" }
  coordinate := "node-1"
  digests := recompute { identity := "doc-1", revision := "3" } "node-1" "obs-a" "abc"
  residuals := ResidualSet.ofList ["distinct-1"]
  observations := "obs-a"
  evidence := "abc"

def expected : Expected String String String String String where
  ruleRevision := "example@1"
  source := { identity := "doc-1", revision := "3" }
  coordinate := "node-1"
  observations := "obs-a"
  residuals := ResidualSet.ofList ["distinct-1"]

#eval match admit certificate expected recompute "caller" with
  | .ok _ => "accepted"
  | .error m => s!"rejected: {m.expected}"

example : ∃ k, admit (P := String) certificate expected recompute "caller" = .ok k :=
  admit_complete rfl rfl rfl rfl rfl rfl
```

`#eval` の結果は `"accepted"` です。

## ライブラリと実行ファイル

| 名前 | 種類 | 内容 |
|---|---|---|
| `NecoQuotient` | ライブラリ | 定義と定理 |
| `Comparison` | ライブラリ | 言語間の比較で使う事例の読み込み、正規 JSON、SHA-256 |
| `certificate_compare` | 実行ファイル | 比較事例に Lean の照合を適用する |

比較事例を再生成する手順は [比較事例の README](../comparison/certificate-admit/README.md) にあります。
