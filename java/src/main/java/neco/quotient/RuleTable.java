package neco.quotient;

import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * 規則のリビジョンをキーとする規則の表。
 *
 * <p>構築後はリビジョンと規則の列を固定する。入力の列は構築時に複製する。
 *
 * @param <S> 入力の識別子の型
 * @param <Rev> 入力のリビジョンの型
 * @param <C> 座標の型
 * @param <Obs> 観測の型
 * @param <E> 証拠の型
 */
public final class RuleTable<S, Rev, C, Obs, E> {

    private final List<RuleEntry<S, Rev, C, Obs, E>> entries;

    private RuleTable(List<RuleEntry<S, Rev, C, Obs, E>> entries) {
        this.entries = entries;
    }

    /**
     * 表を構築する。同じ規則のリビジョンが二度以上現れる場合は、最初に再出現したリビジョンを {@link DuplicateRule} の値として返す。
     *
     * @param entries 規則のリビジョンと規則の組の列
     * @param <S> 入力の識別子の型
     * @param <Rev> 入力のリビジョンの型
     * @param <C> 座標の型
     * @param <Obs> 観測の型
     * @param <E> 証拠の型
     * @return 構築した表、または重複した規則のリビジョン
     */
    public static <S, Rev, C, Obs, E> Result<RuleTable<S, Rev, C, Obs, E>, DuplicateRule> of(
            List<RuleEntry<S, Rev, C, Obs, E>> entries) {
        List<RuleEntry<S, Rev, C, Obs, E>> copy = List.copyOf(entries);
        Set<String> seen = new HashSet<>();
        for (RuleEntry<S, Rev, C, Obs, E> entry : copy) {
            if (!seen.add(entry.ruleRevision())) {
                return new Result.Rejected<>(new DuplicateRule(entry.ruleRevision()));
            }
        }
        return new Result.Accepted<>(new RuleTable<>(copy));
    }

    Optional<Rule<S, Rev, C, Obs, E>> lookup(String ruleRevision) {
        return entries.stream()
                .filter(entry -> entry.ruleRevision().equals(ruleRevision))
                .map(RuleEntry::rule)
                .findFirst();
    }
}
