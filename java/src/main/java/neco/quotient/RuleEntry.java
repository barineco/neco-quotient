package neco.quotient;

import java.util.Objects;

public record RuleEntry<S, Rev, C, Obs, E>(String ruleRevision, Rule<S, Rev, C, Obs, E> rule) {
    public RuleEntry {
        Objects.requireNonNull(ruleRevision, "ruleRevision");
        Objects.requireNonNull(rule, "rule");
    }
}
