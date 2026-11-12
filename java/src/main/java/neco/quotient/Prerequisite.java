package neco.quotient;

public sealed interface Prerequisite<Failure, Children> permits Prerequisite.Failed, Prerequisite.Established {

    record Failed<F, C>(F failure) implements Prerequisite<F, C> {
    }

    record Established<F, C>(C children) implements Prerequisite<F, C> {
    }
}
