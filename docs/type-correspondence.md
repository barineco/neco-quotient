# 言語間の型対応

証明書照合の共通概念を、Lean と五つの実装言語がどの型と識別子で表すかをまとめます。各型が表す関係は、次の文書に記載されています。

- 用語の意味: [terminology.md](terminology.md)
- 照合の条件: [docs/certificate.md](certificate.md)

## 共通概念と実装上の型

Lean と五つの実装言語は、共通概念を次の型名で表します。

| 項目 | 型 |
|---|---|
| 入力参照 | `SourceRef` |
| 射影ダイジェスト | `ProjectionDigest` |
| 残余集合 | `ResidualSet` |
| 証明書 | `Certificate` |
| 期待値 | `Expected` |
| 規則 | `Rule` |
| 規則の表 | `RuleTable` |
| リビジョンの重複 | `DuplicateRule` |
| 照合済みの値 | `Checked` |
| 不一致 | `Mismatch` |
| 照合の条件 | `Condition` |
| 不一致の対象 | `Origin` |

言語によって表し方が異なる項目:

| 項目 | 言語 | 表し方 |
|---|---|---|
| 規則 | Rust | `Rule` トレイト |
| リビジョンの重複 | Lean | 型を持たず、同じリビジョンの先頭を選ぶ |
| 照合 | Lean | `admitWithRules` |
| 照合 | Rust、TypeScript、Python | `admit` |
| 照合 | Java | `Checked.admit` |
| 照合 | Gleam | `admission.admit` |
| 照合の結果 | Lean | `Except` |
| 照合の結果 | Python | `Checked` と `Mismatch` の和 |
| 照合の結果 | Python 以外の実装言語 | `Result` |
| 精密化の判定の状態 | Lean | `RefinementStatus` |
| 精密化の判定の状態 | 五つの実装言語 | `RefinementOutcome` |

Lean の規則の表は、規則のリビジョンと規則の組からなるリストです。言語間の比較では、リビジョンが一意な表を入力に使います。

## 型引数

公開型の型引数は次の対象を表します。

| 型引数 | 表す対象 |
|---|---|
| `S` | 入力の識別子 |
| `Rev` | 入力のリビジョン |
| `C` | 座標 |
| `Obs` | 同一視に用いる観測 |
| `R` | 残余の要素 |
| `E` | 証拠 |
| `P` | 来歴 |

規則のリビジョンは文字列の欄で表されます。主要な型と型引数の対応:

| 型 | 型引数 |
|---|---|
| SourceRef | S, Rev |
| Certificate | S, Rev, C, Obs, R, E |
| Expected | S, Rev, C, Obs, R |
| Rule | S, Rev, C, Obs, E |
| RuleTable | S, Rev, C, Obs, E |
| Checked | S, Rev, C, Obs, R, E |
| Mismatch | P |

Gleam は型引数を小文字で表し、同じ順序を使います。

## 欄名

欄名には二つの形式があります。

- camelCase: Lean, TypeScript, Java
- snake_case: Rust, Python, Gleam

| 関係 | camelCase | snake_case |
|---|---|---|
| 規則のリビジョン | `ruleRevision` | `rule_revision` |
| 入力の識別子 | `identity` | `identity` |
| 入力のリビジョン | `revision` | `revision` |
| 座標 | `coordinate` | `coordinate` |
| 射影ダイジェスト | `digests` | `digests` |
| 残余 | `residuals` | `residuals` |
| 観測 | `observations` | `observations` |
| 証拠 | `evidence` | `evidence` |

## 照合の条件

各言語は、次の六つの条件を同じ並びで宣言します。

1. `decode`: 規則のリビジョンと登録
2. `source`: 入力参照
3. `coordinate`: 座標
4. `observations`: 観測
5. `digest`: 射影ダイジェスト
6. `residual`: 残余

## `DigestScope`

射影ダイジェストを比べられる範囲は、同じ実行環境の内側と、規約を共有する言語の間の二種類です。

| 言語 | 同じ実行環境内 | 言語間 |
|---|---|---|
| Lean | `withinRuntime` | `crossLanguage` |
| Rust | `WithinRuntime` | `CrossLanguage` |
| TypeScript | `"within_runtime"` | `"cross_language"` |
| Java | `DigestScope.WithinRuntime` | `DigestScope.CrossLanguage` |
| Python | `WithinRuntime` | `CrossLanguage` |
| Gleam | `WithinRuntime` | `CrossLanguage` |

TypeScript では、`kind` の値で二つの範囲を区別します。

比較範囲の名前を保持する位置:

- Lean: `runtime` または `encoding`
- TypeScript: `runtime` または `encoding`
- Rust: 構築子の payload
- Java: 構築子の payload
- Python: 各クラスの `name`
- Gleam: 構築子の payload
