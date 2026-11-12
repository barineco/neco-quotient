package neco.quotient;

public sealed interface Result<V, E> permits Result.Accepted, Result.Rejected {

    record Accepted<V, E>(V value) implements Result<V, E> {
    }

    record Rejected<V, E>(E error) implements Result<V, E> {
    }
}
