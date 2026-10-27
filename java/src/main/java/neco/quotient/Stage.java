package neco.quotient;

import java.util.Locale;

/**
 * 不一致を報告する照合の段階。宣言の順序が検査の順序である。
 */
public enum Stage {
    DECODE,
    SOURCE,
    COORDINATE,
    OBSERVATIONS,
    DIGEST,
    RESIDUAL;

    /**
     * 段階の表示名を返す。
     *
     * @return 小文字の段階の名前
     */
    public String label() {
        return name().toLowerCase(Locale.ROOT);
    }
}
