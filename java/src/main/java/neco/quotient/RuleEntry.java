package neco.quotient;

import java.util.Objects;

/**
 * 規則のリビジョンと、そのリビジョンが指す規則の組。
 *
 * @param ruleRevision 規則のリビジョン
 * @param rule 規則
 * @param <S> 入力の識別子の型
 * @param <Rev> 入力のリビジョンの型
 * @param <C> 座標の型
 * @param <Obs> 観測の型
 * @param <E> 証拠の型
 */
public record RuleEntry<S, Rev, C, Obs, E>(String ruleRevision, Rule<S, Rev, C, Obs, E> rule) {
    public RuleEntry {
        Objects.requireNonNull(ruleRevision, "ruleRevision");
        Objects.requireNonNull(rule, "rule");
    }
}
