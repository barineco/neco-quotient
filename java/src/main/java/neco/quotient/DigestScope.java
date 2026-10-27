package neco.quotient;

import java.util.Objects;

/**
 * 射影ダイジェストを比較できる範囲と、その範囲の名前。
 */
public sealed interface DigestScope permits DigestScope.WithinRuntime, DigestScope.CrossLanguage {

    /**
     * 範囲の payload を返す。
     *
     * @return payload の文字列
     */
    String payload();

    /**
     * 同じ実行環境の内側で比較する射影ダイジェストの範囲。
     *
     * @param payload runtime の名前
     */
    record WithinRuntime(String payload) implements DigestScope {
        public WithinRuntime {
            Objects.requireNonNull(payload, "payload");
        }
    }

    /**
     * 言語間で共有する規約により比較する射影ダイジェストの範囲。
     *
     * @param payload encoding の名前
     */
    record CrossLanguage(String payload) implements DigestScope {
        public CrossLanguage {
            Objects.requireNonNull(payload, "payload");
        }
    }
}
