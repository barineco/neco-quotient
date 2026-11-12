# neco_quotient_certificate ( Gleam )

証明書を期待値と照合する Gleam の package です。

照合の条件は [docs/certificate.md](../docs/certificate.md) に記載されています。

## 導入

- 対象: Erlang
- 実行時の依存: `gleam_stdlib` のみ
- 動作を確かめたバージョン: Gleam 1.19.1、Erlang/OTP 29

リポジトリを取得し、利用する側の `gleam.toml` にパスで指定します。

```sh
git clone https://github.com/barineco/neco-quotient.git
```

```toml
[dependencies]
neco_quotient_certificate = { path = "../neco-quotient/gleam" }
```

## 使用例

`RuleTable` を作り、証明書を期待値と照合する例:

```gleam
import gleam/dict
import gleam/int
import gleam/io
import neco_quotient_certificate/admission
import neco_quotient_certificate/certificate.{
  Certificate, Expected, residual_set,
}
import neco_quotient_certificate/digest.{CrossLanguage, ProjectionDigest}
import neco_quotient_certificate/failure
import neco_quotient_certificate/rule_table
import neco_quotient_certificate/source.{type SourceRef, SourceRef}

fn demo_rule(
  src: SourceRef(String, Int),
  coordinate: Int,
  observations: Int,
  evidence: Int,
) {
  let text =
    src.identity
    <> "@"
    <> int.to_string(src.revision)
    <> ":"
    <> int.to_string(coordinate + observations + evidence)
  dict.from_list([
    #("graph", ProjectionDigest(digest: text, scope: CrossLanguage("demo@1"))),
  ])
}

pub fn main() {
  let assert Ok(table) = rule_table.new([#("demo@1", demo_rule)])
  let src = SourceRef(identity: "body", revision: 7)
  let cert =
    Certificate(
      rule_revision: "demo@1",
      source: src,
      coordinate: 1,
      digests: demo_rule(src, 1, 3, 5),
      residuals: residual_set([2]),
      observations: 3,
      evidence: 5,
    )
  let expected =
    Expected(
      rule_revision: "demo@1",
      source: src,
      coordinate: 1,
      observations: 3,
      residuals: residual_set([2]),
    )
  case
    admission.admit(
      table,
      cert,
      expected,
      "caller",
      fn(text) { text },
      int.to_string,
    )
  {
    Ok(checked) ->
      io.println(int.to_string(dict.size(admission.recomputed(checked))))
    Error(mismatch) -> io.println(failure.describe(mismatch))
  }
}
```

例では、整数 `3` を観測の値として使います。この値から観測関数族を得る対応は、利用する側が定めます。

## Gleam での表し方

照合の関数 `admission.admit` の最後の二つの引数には、入力の識別子とリビジョンをそれぞれ文字列にする関数を渡します。

結果は `Result` で表され、成功の値 `Checked` を作れるのは照合の関数だけです。型の言語間の対応は [docs/type-correspondence.md](../docs/type-correspondence.md) にあります。

## 検査

`gleam` のディレクトリで、次のコマンドを実行します。

```sh
gleam test
gleam format --check src test
```

## ライセンス

MIT
