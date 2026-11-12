# neco-quotient-certificate ( Python )

証明書を期待値と照合する Python の package です。

照合の条件は [docs/certificate.md](../docs/certificate.md) に記載されています。

## 導入

Python 3.14 以降で動作し、標準ライブラリのみに依存します。リポジトリの `python` ディレクトリから導入します。

```bash
pip install "git+https://github.com/barineco/neco-quotient.git#subdirectory=python"
```

## 使用例

`RuleTable` を作り、証明書を期待値と照合する例:

```python
from neco_quotient_certificate import (
    Certificate,
    Checked,
    Condition,
    CrossLanguage,
    Expected,
    ProjectionDigest,
    ResidualSet,
    RuleTable,
    SourceRef,
    admit,
)


def evidence_rule(source, coordinate, observations, evidence):
    return {"evidence": ProjectionDigest(evidence.upper(), CrossLanguage("example"))}


table = RuleTable.of([("example@1", evidence_rule)])
assert isinstance(table, RuleTable)

certificate = Certificate(
    rule_revision="example@1",
    source=SourceRef("source-alpha", "rev-1"),
    coordinate="coord-a",
    digests={"evidence": ProjectionDigest("ABC", CrossLanguage("example"))},
    residuals=ResidualSet(("residual-a",)),
    observations="observations-a",
    evidence="abc",
)
expected = Expected(
    rule_revision="example@1",
    source=SourceRef("source-alpha", "rev-1"),
    coordinate="coord-a",
    observations="observations-a",
    residuals=ResidualSet(("residual-a",)),
)

result = admit(table, certificate, expected, provenance="caller/example")
if isinstance(result, Checked):
    print("accepted", result.recomputed)
else:
    print("rejected", result.status_at(Condition.DIGEST))
```

実行すると `accepted` と再計算した射影ダイジェストの写像が表示されます。

## Python での表し方

照合と表の構築の結果は和で表され、`isinstance` で区別します。

- 照合: `Checked` または `Mismatch`
- 表の構築 `RuleTable.of`: 表または `DuplicateRule`

型の言語間の対応は [docs/type-correspondence.md](../docs/type-correspondence.md) にあります。

## 検査

`python` のディレクトリで、次のコマンドを実行します。

```bash
python3 -m unittest discover -s tests -v
```

## ライセンス

MIT
