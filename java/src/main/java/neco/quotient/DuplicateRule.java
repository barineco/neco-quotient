package neco.quotient;

import java.util.Objects;

public record DuplicateRule(String ruleRevision) {
    public DuplicateRule {
        Objects.requireNonNull(ruleRevision, "ruleRevision");
    }
}
