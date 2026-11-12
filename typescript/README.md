# neco-quotient-certificate ( TypeScript )

証明書を期待値と照合する TypeScript の実装です。

照合の条件は [docs/certificate.md](../docs/certificate.md) に記載されています。

## 導入

Node.js 24.11.0 以降で動作し、実行時には ECMAScript の標準の機能のみを使います。リポジトリを取得してビルドします。

```bash
git clone https://github.com/barineco/neco-quotient.git
cd neco-quotient/typescript
npm install
npm run build
```

利用する側のプロジェクトでは、ビルドしたディレクトリをパスで指定します。

```bash
npm install ../neco-quotient/typescript
```

## 使用例

`RuleTable` を作り、証明書を期待値と照合する例:

```ts
import { RuleTable, admit, projectionDigests, residualSet, type Comparison, type Rule } from "neco-quotient-certificate";

const rule: Rule<string, string, string, string, string> = (source, coordinate, observations, evidence) => ({
  evidence: {
    digest: evidence,
    scope: { kind: "cross_language", encoding: "identity" },
  },
});

const table = RuleTable.create([["rule@1", rule]]);
if (!table.ok) throw new Error(`duplicate rule ${table.error.ruleRevision}`);

const comparison: Comparison<string, string, string, string, string> = {
  sameSource: (left, right) => left === right,
  sameRevision: (left, right) => left === right,
  sameCoordinate: (left, right) => left === right,
  sameObservations: (left, right) => left === right,
  sameResidual: (left, right) => left === right,
  identityText: (identity) => identity,
  revisionText: (revision) => revision,
};

const result = admit(
  table.value,
  {
    ruleRevision: "rule@1",
    source: { identity: "source-alpha", revision: "rev-1" },
    coordinate: "coord-a",
    digests: projectionDigests({ evidence: { digest: "d", scope: { kind: "cross_language", encoding: "identity" } } }),
    residuals: residualSet(["residual-a"]),
    observations: "observations-a",
    evidence: "d",
  },
  {
    ruleRevision: "rule@1",
    source: { identity: "source-alpha", revision: "rev-1" },
    coordinate: "coord-a",
    observations: "observations-a",
    residuals: residualSet(["residual-a"]),
  },
  { caller: "run-1" },
  comparison,
);

if (result.ok) {
  console.log(result.value.recomputed.entries());
}
```

結果は `ok` で区別されます。

- 成功: `value` に照合を通過した `Checked` が入る
- 失敗: `error` に不成立の条件と未照合の条件を全て持つ `Mismatch` が入る

## TypeScript での表し方

照合の関数には、各フィールドの等しさを判定する関数の組 `Comparison` を渡します。文字列のフィールドであれば、`===` で比べる関数で足ります。

`Checked` の構築子は非公開で、成功の値を作れるのは `admit` だけです。型の言語間の対応は [docs/type-correspondence.md](../docs/type-correspondence.md) にあります。

## 検査

```bash
npm test
npm run typecheck
```

## ライセンス

MIT
