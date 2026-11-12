package neco.quotient;

import java.util.Collection;
import java.util.Map;
import java.util.Objects;

public record Certificate<S, Rev, C, Obs, R, E>(
        String ruleRevision,
        SourceRef<S, Rev> source,
        C coordinate,
        Map<String, ProjectionDigest> digests,
        ResidualSet<R> residuals,
        Obs observations,
        E evidence) {

    public Certificate {
        digests = Utf8Order.copy(digests);
        residuals = Objects.requireNonNull(residuals, "residuals");
    }

    public Certificate(String ruleRevision, SourceRef<S, Rev> source, C coordinate,
            Map<String, ProjectionDigest> digests, Collection<? extends R> residuals,
            Obs observations, E evidence) {
        this(ruleRevision, source, coordinate, digests, ResidualSet.of(residuals), observations, evidence);
    }
}
