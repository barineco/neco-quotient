package neco.quotient;

import java.util.Map;
import java.util.Objects;
import java.util.SortedMap;

public final class Checked<S, Rev, C, Obs, R, E> {

    private final RuleTable<S, Rev, C, Obs, E> table;
    private final Certificate<S, Rev, C, Obs, R, E> certificate;
    private final Expected<S, Rev, C, Obs, R> expected;
    private final SortedMap<String, ProjectionDigest> recomputed;

    private Checked(
            RuleTable<S, Rev, C, Obs, E> table,
            Certificate<S, Rev, C, Obs, R, E> certificate,
            Expected<S, Rev, C, Obs, R> expected,
            Map<String, ProjectionDigest> recomputed) {
        this.table = table;
        this.certificate = certificate;
        this.expected = expected;
        this.recomputed = Utf8Order.copy(recomputed);
    }

    private record Evaluation<P>(
            AdmissionChecks<P> checks, Prerequisite<ConditionFailure<P>, Map<String, ProjectionDigest>> recompute) {}

    private static <S, Rev, C, Obs, R, E, P> Evaluation<P> evaluate(
            RuleTable<S, Rev, C, Obs, E> table,
            Certificate<S, Rev, C, Obs, R, E> certificate,
            Expected<S, Rev, C, Obs, R> expected,
            P provenance) {
        Objects.requireNonNull(table, "table");
        Objects.requireNonNull(certificate, "certificate");
        Objects.requireNonNull(expected, "expected");
        Prerequisite<ConditionFailure<P>, Map<String, ProjectionDigest>> recompute =
                table.select(certificate, expected, provenance);
        return new Evaluation<>(AdmissionChecks.of(certificate, expected, recompute, provenance), recompute);
    }

    public static <S, Rev, C, Obs, R, E, P> AdmissionChecks<P> check(
            RuleTable<S, Rev, C, Obs, E> table,
            Certificate<S, Rev, C, Obs, R, E> certificate,
            Expected<S, Rev, C, Obs, R> expected,
            P provenance) {
        return evaluate(table, certificate, expected, provenance).checks();
    }

    public static <S, Rev, C, Obs, R, E, P> Result<Checked<S, Rev, C, Obs, R, E>, Mismatch<P>> admit(
            RuleTable<S, Rev, C, Obs, E> table,
            Certificate<S, Rev, C, Obs, R, E> certificate,
            Expected<S, Rev, C, Obs, R> expected,
            P provenance) {
        Evaluation<P> evaluation = evaluate(table, certificate, expected, provenance);
        if (evaluation.checks().allMatched()
                && evaluation.recompute() instanceof Prerequisite.Established<ConditionFailure<P>, Map<String, ProjectionDigest>>(
                        var recomputed)) {
            return new Result.Accepted<>(new Checked<>(table, certificate, expected, recomputed));
        }
        return new Result.Rejected<>(Mismatch.of(evaluation.checks()));
    }

    public Certificate<S, Rev, C, Obs, R, E> certificate() {
        return certificate;
    }

    public Expected<S, Rev, C, Obs, R> expected() {
        return expected;
    }

    public SourceRef<S, Rev> source() {
        return certificate.source();
    }

    public Map<String, ProjectionDigest> recomputed() {
        return recomputed;
    }
}
