package neco.quotient;

import java.util.Objects;

/**
 * 表の中で二度以上現れる規則のリビジョン。
 *
 * @param ruleRevision 最初に再出現した規則のリビジョン
 */
public record DuplicateRule(String ruleRevision) {
    public DuplicateRule {
        Objects.requireNonNull(ruleRevision, "ruleRevision");
    }
}
