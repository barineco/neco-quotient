package neco.quotient;

public sealed interface Status<P>
        permits Status.Matched, Status.Mismatched, Status.UncheckedByDecode, Status.UncheckedBySource {

    record Matched<P>() implements Status<P> {
    }

    record Mismatched<P>() implements Status<P> {
    }

    record UncheckedByDecode<P>(ConditionFailure<P> failure) implements Status<P> {
    }

    record UncheckedBySource<P>(ConditionFailure<P> failure) implements Status<P> {
    }

    static <P> Status<P> ofBool(boolean matched) {
        return matched ? new Matched<>() : new Mismatched<>();
    }
}
