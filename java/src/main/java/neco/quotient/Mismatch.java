package neco.quotient;

import java.util.ArrayList;
import java.util.List;

public final class Mismatch<P> {

    private final AdmissionChecks<P> checks;

    private Mismatch(AdmissionChecks<P> checks) {
        this.checks = checks;
    }

    static <P> Mismatch<P> of(AdmissionChecks<P> checks) {
        if (checks.allMatched()) {
            throw new IllegalArgumentException("a mismatch needs at least one failed condition");
        }
        return new Mismatch<>(checks);
    }

    public AdmissionChecks<P> checks() {
        return checks;
    }

    public Origin origin() {
        return checks.origin();
    }

    public P provenance() {
        return checks.provenance();
    }

    public Status<P> statusAt(Condition condition) {
        return checks.statusAt(condition);
    }

    public String describe() {
        List<String> parts = new ArrayList<>();
        if (checks.decode() instanceof Prerequisite.Failed<ConditionFailure<P>, DigestChecks>(var failure)) {
            parts.add(detail("decode", failure));
        } else if (checks.decode() instanceof Prerequisite.Established<ConditionFailure<P>, DigestChecks>(var digests)) {
            digests.results().forEach((name, result) -> {
                if (!result.isMatched()) {
                    parts.add("digest " + name + " " + result.label());
                }
            });
        }
        if (checks.source() instanceof Prerequisite.Failed<ConditionFailure<P>, SourceChecks<P>>(var failure)) {
            parts.add(detail("source", failure));
        } else if (checks.source() instanceof Prerequisite.Established<ConditionFailure<P>, SourceChecks<P>>(var children)) {
            addCheck(parts, "coordinate", children.coordinate());
            addCheck(parts, "observations", children.observations());
            addCheck(parts, "residual", children.residual());
        }
        Origin origin = checks.origin();
        return "admit failed (rule " + origin.ruleRevision()
                + ", source " + origin.sourceIdentity() + "@" + origin.sourceRevision()
                + "): " + String.join("; ", parts);
    }

    private static <P> void addCheck(List<String> parts, String name, CheckResult<ConditionFailure<P>> check) {
        if (check instanceof CheckResult.Mismatched<ConditionFailure<P>>(var failure)) {
            parts.add(detail(name, failure));
        }
    }

    private static <P> String detail(String name, ConditionFailure<P> failure) {
        return name + " expected " + failure.expected() + ", actual " + failure.actual();
    }
}
