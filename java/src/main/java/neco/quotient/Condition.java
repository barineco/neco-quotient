package neco.quotient;

import java.util.Optional;

public enum Condition {
    DECODE,
    SOURCE,
    COORDINATE,
    OBSERVATIONS,
    DIGEST,
    RESIDUAL;

    public Optional<Condition> prerequisite() {
        return switch (this) {
            case DECODE, SOURCE -> Optional.empty();
            case DIGEST -> Optional.of(DECODE);
            case COORDINATE, OBSERVATIONS, RESIDUAL -> Optional.of(SOURCE);
        };
    }
}
