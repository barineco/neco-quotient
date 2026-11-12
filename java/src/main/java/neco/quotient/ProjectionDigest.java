package neco.quotient;

import java.util.Objects;

public record ProjectionDigest(String digest, DigestScope scope) {
    public ProjectionDigest {
        Objects.requireNonNull(digest, "digest");
        Objects.requireNonNull(scope, "scope");
    }
}
