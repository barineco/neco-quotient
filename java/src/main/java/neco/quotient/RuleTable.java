package neco.quotient;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

public final class RuleTable<S, Rev, C, Obs, E> {

    private final List<RuleEntry<S, Rev, C, Obs, E>> entries;

    private RuleTable(List<RuleEntry<S, Rev, C, Obs, E>> entries) {
        this.entries = entries;
    }

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

    <R, P> Prerequisite<ConditionFailure<P>, Map<String, ProjectionDigest>> select(
            Certificate<S, Rev, C, Obs, R, E> certificate,
            Expected<S, Rev, C, Obs, R> expected,
            P provenance) {
        Origin origin = Origin.of(certificate);
        if (!certificate.ruleRevision().equals(expected.ruleRevision())) {
            return new Prerequisite.Failed<>(ConditionFailure.admit(Condition.DECODE,
                    expected.ruleRevision(), certificate.ruleRevision(), origin, provenance));
        }
        Optional<Rule<S, Rev, C, Obs, E>> rule = lookup(certificate.ruleRevision());
        if (rule.isEmpty()) {
            return new Prerequisite.Failed<>(ConditionFailure.admit(Condition.DECODE,
                    "rule in table", certificate.ruleRevision(), origin, provenance));
        }
        return new Prerequisite.Established<>(Utf8Order.copy(rule.get().recompute(
                certificate.source(), certificate.coordinate(), certificate.observations(), certificate.evidence())));
    }

    Optional<Rule<S, Rev, C, Obs, E>> lookup(String ruleRevision) {
        return entries.stream()
                .filter(entry -> entry.ruleRevision().equals(ruleRevision))
                .map(RuleEntry::rule)
                .findFirst();
    }
}
