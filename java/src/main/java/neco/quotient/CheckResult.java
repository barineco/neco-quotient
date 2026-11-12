package neco.quotient;

import java.util.function.Supplier;

public sealed interface CheckResult<F> permits CheckResult.Matched, CheckResult.Mismatched {

    record Matched<F>() implements CheckResult<F> {
    }

    record Mismatched<F>(F failure) implements CheckResult<F> {
    }

    default boolean isMatched() {
        return this instanceof Matched<F>;
    }

    static <F> CheckResult<F> of(boolean holds, Supplier<F> failure) {
        return holds ? new Matched<>() : new Mismatched<>(failure.get());
    }
}
