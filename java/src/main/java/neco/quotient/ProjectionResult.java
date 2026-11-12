package neco.quotient;

public sealed interface ProjectionResult
        permits ProjectionResult.Matched, ProjectionResult.CertificateOnly,
        ProjectionResult.RecomputedOnly, ProjectionResult.Different {

    record Matched(ProjectionDigest value) implements ProjectionResult {
    }

    record CertificateOnly(ProjectionDigest actual) implements ProjectionResult {
    }

    record RecomputedOnly(ProjectionDigest expected) implements ProjectionResult {
    }

    record Different(ProjectionDigest expected, ProjectionDigest actual) implements ProjectionResult {
    }

    static ProjectionResult of(ProjectionDigest expected, ProjectionDigest actual) {
        if (expected == null) {
            return new CertificateOnly(actual);
        }
        if (actual == null) {
            return new RecomputedOnly(expected);
        }
        return expected.equals(actual) ? new Matched(expected) : new Different(expected, actual);
    }

    default boolean isMatched() {
        return this instanceof Matched;
    }

    default String label() {
        return switch (this) {
            case Matched matched -> "matched";
            case CertificateOnly certificateOnly -> "certificate_only";
            case RecomputedOnly recomputedOnly -> "recomputed_only";
            case Different different -> "different";
        };
    }
}
