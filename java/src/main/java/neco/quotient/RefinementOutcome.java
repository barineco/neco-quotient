package neco.quotient;

import java.util.Collection;
import java.util.Objects;

public sealed interface RefinementOutcome<V, R, S>
        permits RefinementOutcome.Resolved, RefinementOutcome.Residual, RefinementOutcome.Stopped {

    V value();

    record Resolved<V, R, S>(V value) implements RefinementOutcome<V, R, S> {
    }

    record Residual<V, R, S>(V value, ResidualSet<R> residuals) implements RefinementOutcome<V, R, S> {

        public Residual {
            residuals = Objects.requireNonNull(residuals, "residuals");
        }

        public Residual(V value, Collection<? extends R> residuals) {
            this(value, ResidualSet.of(residuals));
        }
    }

    record Stopped<V, R, S>(V value, ResidualSet<R> residuals, S cause) implements RefinementOutcome<V, R, S> {

        public Stopped {
            residuals = Objects.requireNonNull(residuals, "residuals");
        }

        public Stopped(V value, Collection<? extends R> residuals, S cause) {
            this(value, ResidualSet.of(residuals), cause);
        }
    }
}
