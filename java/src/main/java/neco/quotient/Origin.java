package neco.quotient;

public record Origin(String ruleRevision, String sourceIdentity, String sourceRevision) {

    static <S, Rev, C, Obs, R, E> Origin of(Certificate<S, Rev, C, Obs, R, E> certificate) {
        return new Origin(certificate.ruleRevision(), String.valueOf(certificate.source().identity()),
                String.valueOf(certificate.source().revision()));
    }
}
