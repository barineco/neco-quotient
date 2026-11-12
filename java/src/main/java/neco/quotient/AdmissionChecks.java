package neco.quotient;

import java.util.Map;
import java.util.Objects;
import java.util.function.Function;

public record AdmissionChecks<P>(
        Origin origin,
        P provenance,
        Prerequisite<ConditionFailure<P>, DigestChecks> decode,
        Prerequisite<ConditionFailure<P>, SourceChecks<P>> source) {

    public boolean allMatched() {
        return decode instanceof Prerequisite.Established<ConditionFailure<P>, DigestChecks>(var digests)
                && digests.allMatched()
                && source instanceof Prerequisite.Established<ConditionFailure<P>, SourceChecks<P>>(var children)
                && children.allMatched();
    }

    public Status<P> statusAt(Condition condition) {
        return switch (condition) {
            case DECODE -> Status.ofBool(decode instanceof Prerequisite.Established<?, ?>);
            case SOURCE -> Status.ofBool(source instanceof Prerequisite.Established<?, ?>);
            case DIGEST -> switch (decode) {
                case Prerequisite.Failed<ConditionFailure<P>, DigestChecks> failed ->
                        new Status.UncheckedByDecode<>(failed.failure());
                case Prerequisite.Established<ConditionFailure<P>, DigestChecks> established ->
                        Status.ofBool(established.children().allMatched());
            };
            case COORDINATE -> sourceStatus(SourceChecks::coordinate);
            case OBSERVATIONS -> sourceStatus(SourceChecks::observations);
            case RESIDUAL -> sourceStatus(SourceChecks::residual);
        };
    }

    private Status<P> sourceStatus(Function<SourceChecks<P>, CheckResult<ConditionFailure<P>>> select) {
        return switch (source) {
            case Prerequisite.Failed<ConditionFailure<P>, SourceChecks<P>> failed ->
                    new Status.UncheckedBySource<>(failed.failure());
            case Prerequisite.Established<ConditionFailure<P>, SourceChecks<P>> established ->
                    Status.ofBool(select.apply(established.children()).isMatched());
        };
    }

    static <S, Rev, C, Obs, R, E, P> AdmissionChecks<P> of(
            Certificate<S, Rev, C, Obs, R, E> certificate,
            Expected<S, Rev, C, Obs, R> expected,
            Prerequisite<ConditionFailure<P>, Map<String, ProjectionDigest>> recompute,
            P provenance) {
        Objects.requireNonNull(certificate, "certificate");
        Objects.requireNonNull(expected, "expected");
        Origin origin = Origin.of(certificate);
        Prerequisite<ConditionFailure<P>, DigestChecks> decode = switch (recompute) {
            case Prerequisite.Failed<ConditionFailure<P>, Map<String, ProjectionDigest>> failed ->
                    new Prerequisite.Failed<>(failed.failure());
            case Prerequisite.Established<ConditionFailure<P>, Map<String, ProjectionDigest>> established ->
                    new Prerequisite.Established<>(DigestChecks.check(established.children(), certificate.digests()));
        };
        Prerequisite<ConditionFailure<P>, SourceChecks<P>> source;
        if (certificate.source().equals(expected.source())) {
            source = new Prerequisite.Established<>(new SourceChecks<>(
                    CheckResult.of(Objects.equals(certificate.coordinate(), expected.coordinate()),
                            () -> ConditionFailure.admit(Condition.COORDINATE, String.valueOf(expected.coordinate()),
                                    String.valueOf(certificate.coordinate()), origin, provenance)),
                    CheckResult.of(Objects.equals(certificate.observations(), expected.observations()),
                            () -> ConditionFailure.admit(Condition.OBSERVATIONS, String.valueOf(expected.observations()),
                                    String.valueOf(certificate.observations()), origin, provenance)),
                    CheckResult.of(certificate.residuals().equals(expected.residuals()),
                            () -> ConditionFailure.admit(Condition.RESIDUAL, String.valueOf(expected.residuals().values()),
                                    String.valueOf(certificate.residuals().values()), origin, provenance))));
        } else {
            source = new Prerequisite.Failed<>(ConditionFailure.admit(Condition.SOURCE, sourceText(expected.source()),
                    sourceText(certificate.source()), origin, provenance));
        }
        return new AdmissionChecks<>(origin, provenance, decode, source);
    }

    private static <S, Rev> String sourceText(SourceRef<S, Rev> source) {
        return String.valueOf(source.identity()) + "@" + String.valueOf(source.revision());
    }
}
