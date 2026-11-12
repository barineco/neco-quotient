package neco.quotient;

import java.util.Objects;

public final class ConditionFailure<P> {

    private final Condition condition;
    private final String operation;
    private final String expected;
    private final String actual;
    private final Origin origin;
    private final P provenance;

    private ConditionFailure(Condition condition, String expected, String actual, Origin origin, P provenance) {
        this.condition = Objects.requireNonNull(condition, "condition");
        this.operation = "admit";
        this.expected = expected;
        this.actual = actual;
        this.origin = origin;
        this.provenance = provenance;
    }

    static <P> ConditionFailure<P> admit(
            Condition condition, String expected, String actual, Origin origin, P provenance) {
        return new ConditionFailure<>(condition, expected, actual, origin, provenance);
    }

    public Condition condition() {
        return condition;
    }

    public String operation() {
        return operation;
    }

    public String expected() {
        return expected;
    }

    public String actual() {
        return actual;
    }

    public Origin origin() {
        return origin;
    }

    public P provenance() {
        return provenance;
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof ConditionFailure<?> that
                && condition == that.condition
                && operation.equals(that.operation)
                && Objects.equals(expected, that.expected)
                && Objects.equals(actual, that.actual)
                && Objects.equals(origin, that.origin)
                && Objects.equals(provenance, that.provenance);
    }

    @Override
    public int hashCode() {
        return Objects.hash(condition, operation, expected, actual, origin, provenance);
    }

    @Override
    public String toString() {
        return "ConditionFailure[condition=" + condition + ", operation=" + operation + ", expected=" + expected
                + ", actual=" + actual + ", origin=" + origin + ", provenance=" + provenance + "]";
    }
}
