# neco.quotient

証明書を期待値と照合する Java の実装です。

照合の条件は [証明書](../docs/certificate.md) で定めます。

## 導入

JDK 21 以降で動作し、JDK の標準ライブラリのみに依存します。リポジトリを取得し、ソースから JAR を作ります。

```sh
git clone https://github.com/barineco/neco-quotient.git
cd neco-quotient/java
javac -d build/classes $(find src/main -name '*.java')
jar --create --file build/neco-quotient.jar -C build/classes .
```

利用する側は、作った JAR をクラスパスに加えます。

## 使用例

次の例は `Example.java` として保存し、コンパイルして実行できます。

```java
import java.util.List;

import neco.quotient.Certificate;
import neco.quotient.Checked;
import neco.quotient.DigestScope;
import neco.quotient.DuplicateRule;
import neco.quotient.Expected;
import neco.quotient.Mismatch;
import neco.quotient.ProjectionDigest;
import neco.quotient.ResidualSet;
import neco.quotient.Result;
import neco.quotient.Rule;
import neco.quotient.RuleEntry;
import neco.quotient.RuleTable;
import neco.quotient.SourceRef;

public final class Example {
    public static void main(String[] args) {
        Rule<String, String, String, String, String> rule =
                (source, coordinate, observations, evidence) -> List.of(
                        new ProjectionDigest("evidence", "digest-of-" + evidence,
                                new DigestScope.CrossLanguage("example")));
        Result<RuleTable<String, String, String, String, String>, DuplicateRule> built =
                RuleTable.of(List.of(new RuleEntry<>("example@1", rule)));
        if (!(built instanceof Result.Accepted<RuleTable<String, String, String, String, String>, DuplicateRule>(var table))) {
            throw new IllegalStateException("the example revisions are distinct");
        }

        SourceRef<String, String> source = new SourceRef<>("source-alpha", "rev-1");
        Certificate<String, String, String, String, String, String> certificate = new Certificate<>(
                "example@1",
                source,
                "coord-a",
                List.of(new ProjectionDigest("evidence", "digest-of-x", new DigestScope.CrossLanguage("example"))),
                ResidualSet.of(List.of("residual-a")),
                "observations-a",
                "x");
        Expected<String, String, String, String, String> expected = new Expected<>(
                "example@1", source, "coord-a", "observations-a", ResidualSet.of(List.of("residual-a")));

        Result<Checked<String, String, String, String, String, String>, Mismatch<String>> result =
                Checked.admit(table, certificate, expected, "caller");
        if (result instanceof Result.Accepted<Checked<String, String, String, String, String, String>, Mismatch<String>>(var checked)) {
            System.out.println("accepted: " + checked.recomputed());
        } else if (result instanceof Result.Rejected<Checked<String, String, String, String, String, String>, Mismatch<String>>(var mismatch)) {
            System.out.println(mismatch.describe());
        }
    }
}
```

```sh
javac -cp neco-quotient.jar Example.java
java -cp neco-quotient.jar:. Example
```

実行結果:

```text
accepted: [ProjectionDigest[projection=evidence, digest=digest-of-x, scope=CrossLanguage[payload=example]]]
```

## Java での表し方

照合の結果は sealed インターフェース `Result` で表されます。

- 成功: `Result.Accepted`
- 失敗: `Result.Rejected`

照合を通過した値 `Checked` を作れるのは `Checked.admit` だけです。型の言語間の対応は [言語間の型対応](../docs/reference/type-correspondence.md) にあります。

## 検査

標準のアサーションを使うため、`-ea` を付けて起動します。

```sh
cd java
javac -d build/classes $(find src -name '*.java')
java -ea -cp build/classes neco.quotient.CertificateTest
```

ビルドの生成物は、Git の管理対象から除外されています。

## ライセンス

MIT
