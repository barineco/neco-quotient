package neco.quotient;

import java.util.Collection;
import java.util.Objects;

public record Expected<S, Rev, C, Obs, R>(
        String ruleRevision,
        SourceRef<S, Rev> source,
        C coordinate,
        Obs observations,
        ResidualSet<R> residuals) {

    public Expected {
        residuals = Objects.requireNonNull(residuals, "residuals");
    }

    public Expected(String ruleRevision, SourceRef<S, Rev> source, C coordinate,
            Obs observations, Collection<? extends R> residuals) {
        this(ruleRevision, source, coordinate, observations, ResidualSet.of(residuals));
    }
}
