package neco.quotient;

/**
 * 不一致の対象となる証明書のリビジョンと入力。
 *
 * @param ruleRevision 証明書の規則のリビジョン
 * @param sourceIdentity 証明書の入力の識別子
 * @param sourceRevision 証明書の入力のリビジョン
 */
public record Origin(String ruleRevision, String sourceIdentity, String sourceRevision) {
}
