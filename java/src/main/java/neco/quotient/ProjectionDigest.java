package neco.quotient;

import java.util.Objects;

/**
 * 入力の一つの射影ダイジェスト。
 *
 * @param projection 射影の名前
 * @param digest ダイジェストの文字列
 * @param scope ダイジェストを比較できる範囲
 */
public record ProjectionDigest(String projection, String digest, DigestScope scope) {
    public ProjectionDigest {
        Objects.requireNonNull(projection, "projection");
        Objects.requireNonNull(digest, "digest");
        Objects.requireNonNull(scope, "scope");
    }
}
