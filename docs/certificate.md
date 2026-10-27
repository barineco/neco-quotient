# 証明書

証明書は、あるリビジョンの入力について、どの座標をどの観測で区別したかを、射影ダイジェスト、残余、証拠とともに記録します。観測関数族が対象間の同値関係を定める方法については、[観測関数族と商](concepts.md) を参照してください。

## 証明書と期待値

| フィールド | 内容 |
|---|---|
| `rule_revision` | 射影ダイジェストの再計算方法を識別するリビジョン |
| `source` | 証明書が参照する入力の識別子とリビジョン |
| `coordinate` | 入力のうち証明書が対象とする位置 |
| `observations` | 対象間の区別に用いる観測 |
| `digests` | 射影の名前、ダイジェスト文字列、比較範囲からなる列 |
| `residuals` | 照合後も区別として保持する値の集合 |
| `evidence` | 射影ダイジェストの再計算に用いる証拠 |

照合する側は、以上の証明書から `evidence` を除いたフィールドを持つ期待値 `Expected` を与えます。

## 観測

ある値から観測関数族を得る対応は `observations` の具体的な型として表現されます。状態遷移を扱う場合、入力列を $i$、状態を $s$ とし、出力列を得る観測関数 $o_i$ は $o_i(s)=\operatorname{run}(T,s,i)$ として定めます。他の型で観測を表現する場合は、その型の所有者が対応関係を指定します。

## 射影ダイジェスト

`digests` フィールドには射影ダイジェストが列として記録され、各要素は次の三つのフィールドを持ちます。

| フィールド | 内容 |
|---|---|
| `projection` | 射影の名前 |
| `digest` | ダイジェスト文字列 |
| `scope` | 比較範囲 |

比較範囲には次の二種類があります。

- `WithinRuntime`: 指定した実行環境内で比較する
- `CrossLanguage`: 指定した規約を共有する実装の間で比較する

## 残余

`residuals` フィールドには、照合後も区別として保持される値が集合として記録されます。残余集合の同一性は要素の所属で決まり、公開 API では `ResidualSet` が比較を行います。

## 照合

証明書を $c$、期待値を $e$、証明書のリビジョンで選んだ規則の再計算を $\operatorname{recompute}$ とします。照合の処理 `admit` は、次の六つの条件が全て成り立つときに成功します。

$$
\begin{aligned}
c.\mathrm{rule\_revision} &= e.\mathrm{rule\_revision} \\
c.\mathrm{source} &= e.\mathrm{source} \\
c.\mathrm{coordinate} &= e.\mathrm{coordinate} \\
c.\mathrm{observations} &= e.\mathrm{observations} \\
c.\mathrm{digests} &= \operatorname{recompute}(c.\mathrm{source},c.\mathrm{coordinate},c.\mathrm{observations},c.\mathrm{evidence}) \\
\operatorname{same}(c.\mathrm{residuals},e.\mathrm{residuals}) &= \mathrm{true}
\end{aligned}
$$

| 段階 | 条件 |
|---|---|
| `decode` | 規則のリビジョンおよびその登録 |
| `source` | 入力の識別子とリビジョン |
| `coordinate` | 座標 |
| `observations` | 観測 |
| `digest` | 射影ダイジェスト |
| `residual` | 残余 |

照合時は上から順に条件を確かめ、最初の不成立を `Mismatch` として返します。六条件を通過した場合 `Checked` を返します。

同じリビジョンを二つ登録すると `DuplicateRule` が返されるため、`RuleTable` に登録する規則のリビジョンは一意です。

## 外部入力を取得した場合

外部入力の取得は `resolver` が担い、証明書の `SourceRef` から内容と参照を返します。照合時は、証明書と取得結果について、参照の一致および再計算された射影ダイジェストの一致を検証します。

取得が失敗した場合は `ResolvedAdmitFailure` が返されます。この失敗時も、入力の参照と来歴は保持されます。

## JSON 形式

証明書のハッシュ値を言語をまたいで比較するため、証明書を JSON 値で表し、共通の規則でバイト列へと変換します。

- オブジェクトのキーを UTF-8 のバイト列の順に並べる
- 構文上の空白を 0 個にする
- 一つのオブジェクトで各キーを一度だけ使う
- 復号した値を再び符号化した結果が入力と一致する
- 数を文字列で表す

### エスケープ規則

| 文字 | 表現 |
|---|---|
| `"` (引用符) | `\"` |
| `\` (逆斜線) | `\\` |
| U+0008 (バックスペース) | `\b` |
| U+000C (フォームフィード) | `\f` |
| U+000A (改行) | `\n` |
| U+000D (復帰) | `\r` |
| U+0009 (タブ) | `\t` |
| その他の U+0000〜U+001F | `\uXXXX` (小文字4桁) |
| U+0020 以上 | UTF-8 のまま |

### 正規化された例

```json
{
  "coordinate": "node-1",
  "digests": [{"digest": "abc123", "projection": "graph", "scope": {"cross_language": "sha256"}}],
  "evidence": "snapshot-data",
  "observations": ["input-a", "input-b"],
  "residuals": ["distinct-1"],
  "rule_revision": "v1",
  "source": {"identity": "doc-1", "revision": "3"}
}
```

残余と射影ダイジェストは、重複を除いて正規のバイト列の昇順で並べます。証明書のハッシュ値は、この正規形のバイト列に SHA-256 を適用した値です。

## 関連

- 各言語の型と失敗の対応: [五言語の対応](languages.md)
- 符号化の実装: [`neco-quotient-encoding`](../rust/neco-quotient-encoding)
