package neco.quotient;

public record SourceChecks<P>(
        CheckResult<ConditionFailure<P>> coordinate,
        CheckResult<ConditionFailure<P>> observations,
        CheckResult<ConditionFailure<P>> residual) {

    public boolean allMatched() {
        return coordinate.isMatched() && observations.isMatched() && residual.isMatched();
    }
}
