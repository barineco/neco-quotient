package neco.quotient;

import java.io.IOException;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

public final class CertificateTest {

    static final String REVISION = "comparison/sha256@1";
    static final String OTHER_REVISION = "comparison/sha256@2";
    static final String FULLWIDTH_TILDE = "\uFF5E";
    static final String GRINNING_FACE = "\uD83D\uDE00";
    static final DigestScope CROSS = new DigestScope.CrossLanguage("sha256");

    static final Comparator<String> UTF8_BYTES =
            (left, right) -> Arrays.compareUnsigned(left.getBytes(StandardCharsets.UTF_8), right.getBytes(StandardCharsets.UTF_8));

    static final Rule<String, String, String, String, String> COMPARISON =
            (source, coordinate, observations, evidence) -> Map.of("evidence",
                    new ProjectionDigest(ComparisonEvidence.digest(evidence), CROSS));

    private CertificateTest() {
    }

    interface Body {
        void run() throws Exception;
    }

    record TestCase(String name, Body body) {
    }

    public static void main(String[] args) {
        if (!assertionsEnabled()) {
            System.out.println("assertions are disabled; run with java -ea");
            System.exit(2);
        }
        List<TestCase> cases = tests();
        int failed = 0;
        for (TestCase testCase : cases) {
            try {
                testCase.body().run();
                System.out.println("ok   " + testCase.name());
            } catch (Throwable error) {
                failed++;
                System.out.println("FAIL " + testCase.name() + ": " + error);
            }
        }
        System.out.println((cases.size() - failed) + " passed, " + failed + " failed");
        if (failed > 0) {
            System.exit(1);
        }
    }

    static boolean assertionsEnabled() {
        boolean enabled = false;
        assert enabled = true;
        return enabled;
    }

    static List<TestCase> tests() {
        return List.of(
                new TestCase("corpus outcomes equal lean outcomes", CertificateTest::corpusOutcomesEqualLeanOutcomes),
                new TestCase("versioned residual set API cases equal lean outcomes",
                        CertificateTest::residualSetApiCasesEqualLeanOutcomes),
                new TestCase("corpus accepted rows return certificate and recomputed digests",
                        CertificateTest::corpusAcceptedRowsReturnCertificateAndRecomputed),
                new TestCase("corpus rejected rows keep provenance and origin",
                        CertificateTest::corpusRejectedRowsKeepProvenanceAndOrigin),
                new TestCase("json reader decodes escapes and unicode", CertificateTest::jsonReaderDecodesEscapes),
                new TestCase("canonical JSON string escapes", CertificateTest::canonicalStringEscapes),
                new TestCase("canonical JSON object keys follow UTF-8 byte order",
                        CertificateTest::canonicalKeysFollowUtf8Bytes),
                new TestCase("decode failure leaves digest unchecked", CertificateTest::decodeFailureLeavesDigestUnchecked),
                new TestCase("unknown rule is a decode failure", CertificateTest::unknownRuleIsDecodeFailure),
                new TestCase("each condition alone is reported at that condition",
                        CertificateTest::eachConditionAloneIsReported),
                new TestCase("simultaneous root failures are all reported", CertificateTest::simultaneousRootFailuresAreAllReported),
                new TestCase("simultaneous children failures are all reported",
                        CertificateTest::simultaneousChildrenFailuresAreAllReported),
                new TestCase("source failure leaves its children unchecked", CertificateTest::sourceFailureLeavesChildrenUnchecked),
                new TestCase("digest is checked independently of source", CertificateTest::digestIsCheckedIndependentlyOfSource),
                new TestCase("digest names are classified by key", CertificateTest::digestNamesAreClassifiedByKey),
                new TestCase("digest scope kind and payload are compared", CertificateTest::digestScopeKindAndPayloadAreCompared),
                new TestCase("digest insertion order does not change the outcome",
                        CertificateTest::digestInsertionOrderDoesNotChangeOutcome),
                new TestCase("renaming one digest key changes only that name", CertificateTest::renamingOneKeyIsIsolated),
                new TestCase("digest checks iterate in UTF-8 byte order", CertificateTest::digestChecksIterateInUtf8ByteOrder),
                new TestCase("residual order and duplicates compare by membership",
                        CertificateTest::residualMembershipIgnoresOrderAndDuplicates),
                new TestCase("residual membership is compared", CertificateTest::residualMembershipIsCompared),
                new TestCase("duplicate rule revision is a typed failure at construction",
                        CertificateTest::duplicateRuleIsATypedFailureAtConstruction),
                new TestCase("table is independent from the mutable input list",
                        CertificateTest::tableIsIndependentFromInputList),
                new TestCase("table order does not change the selected rule",
                        CertificateTest::tableOrderDoesNotChangeSelectedRule),
                new TestCase("certificate maps are detached from the input maps",
                        CertificateTest::certificateMapsAreDetachedFromInput),
                new TestCase("provenance is returned unchanged", CertificateTest::provenanceIsReturnedUnchanged),
                new TestCase("checked value exposes admitted parts", CertificateTest::checkedValueExposesAdmittedParts),
                new TestCase("check returns checks on acceptance", CertificateTest::checkReturnsChecksOnAcceptance),
                new TestCase("record values compare by components", CertificateTest::recordValuesCompareByComponents),
                new TestCase("mismatch description names failing conditions",
                        CertificateTest::mismatchDescriptionNamesFailingConditions),
                new TestCase("mismatch rejects a fully matched admission", CertificateTest::mismatchRejectsFullyMatchedAdmission),
                new TestCase("failures hold their own condition", CertificateTest::failuresHoldTheirOwnCondition),
                new TestCase("public api boundary", CertificateTest::publicApiBoundary),
                new TestCase("refinement outcome cases hold their parts", CertificateTest::refinementOutcomeCasesHoldTheirParts),
                new TestCase("refinement outcome equal parts are equal", CertificateTest::refinementOutcomeEqualPartsAreEqual),
                new TestCase("refinement outcome residual order and duplicates do not change equality",
                        CertificateTest::refinementOutcomeIgnoresResidualOrder),
                new TestCase("refinement outcome different parts are not equal",
                        CertificateTest::refinementOutcomeDifferentPartsAreNotEqual),
                new TestCase("refinement outcome different cases are not equal",
                        CertificateTest::refinementOutcomeDifferentCasesAreNotEqual),
                new TestCase("refinement outcome comparison equals lean outcomes",
                        CertificateTest::refinementComparisonEqualsLeanOutcomes),
                new TestCase("refinement outcome comparison inputs are canonical",
                        CertificateTest::refinementComparisonInputsAreCanonical),
                new TestCase("refinement outcome comparison separates reordered inputs from swapped cases",
                        CertificateTest::refinementComparisonSeparatesReorderingFromSwappedCases)
        );
    }

    static RuleEntry<String, String, String, String, String> entry(
            String revision, Rule<String, String, String, String, String> rule) {
        return new RuleEntry<>(revision, rule);
    }

    static RuleTable<String, String, String, String, String> built(
            Result<RuleTable<String, String, String, String, String>, DuplicateRule> result) {
        if (result instanceof Result.Accepted<RuleTable<String, String, String, String, String>, DuplicateRule>(
                RuleTable<String, String, String, String, String> table)) {
            return table;
        }
        throw new AssertionError("expected a rule table, got " + result);
    }

    static RuleTable<String, String, String, String, String> comparisonTable() {
        return built(RuleTable.of(List.of(entry(REVISION, COMPARISON))));
    }

    static Map<String, ProjectionDigest> digestsOf(String evidence) {
        return COMPARISON.recompute(new SourceRef<>("source-alpha", "rev-1"), "coord-a", "observations-a", evidence);
    }

    static Expected<String, String, String, String, String> baseExpected() {
        return new Expected<>(REVISION, new SourceRef<>("source-alpha", "rev-1"), "coord-a", "observations-a",
                List.of("residual-a", "residual-b"));
    }

    static final class Draft {
        String ruleRevision = REVISION;
        String identity = "source-alpha";
        String revision = "rev-1";
        String coordinate = "coord-a";
        String observations = "observations-a";
        String evidence = "evidence-plain";
        Map<String, ProjectionDigest> digests = digestsOf("evidence-plain");
        List<String> residuals = List.of("residual-a", "residual-b");

        Certificate<String, String, String, String, String, String> certificate() {
            return new Certificate<>(ruleRevision, new SourceRef<>(identity, revision), coordinate,
                    digests, residuals, observations, evidence);
        }
    }

    static Result<Checked<String, String, String, String, String, String>, Mismatch<String>> admit(Draft draft) {
        return Checked.admit(comparisonTable(), draft.certificate(), baseExpected(), "caller");
    }

    static AdmissionChecks<String> checksOf(RuleTable<String, String, String, String, String> table,
            Certificate<String, String, String, String, String, String> certificate,
            Expected<String, String, String, String, String> expected, String provenance) {
        return AdmissionChecks.of(certificate, expected, table.select(certificate, expected, provenance), provenance);
    }

    static AdmissionChecks<String> checksOfDraft(Draft draft) {
        var table = comparisonTable();
        var certificate = draft.certificate();
        var expected = baseExpected();
        var checks = checksOf(table, certificate, expected, "caller");
        var result = Checked.admit(table, certificate, expected, "caller");
        same(checks.allMatched(), result instanceof Result.Accepted<?, ?>, "acceptance follows the checks");
        return checks;
    }

    static <V, P> V acceptedOf(Result<V, Mismatch<P>> result) {
        if (result instanceof Result.Accepted<V, Mismatch<P>>(V value)) {
            return value;
        }
        throw new AssertionError("expected acceptance, got " + result);
    }

    static <V, P> Mismatch<P> rejectedOf(Result<V, Mismatch<P>> result) {
        if (result instanceof Result.Rejected<V, Mismatch<P>>(Mismatch<P> error)) {
            return error;
        }
        throw new AssertionError("expected rejection, got " + result);
    }

    static void check(boolean condition, String message) {
        assert condition : message;
    }

    static void same(Object expected, Object actual, String message) {
        assert Objects.equals(expected, actual)
                : message + ": expected " + expected + ", actual " + actual;
    }

    static Path corpusDir() {
        return Path.of("..", "comparison", "certificate-admit");
    }

    static Object readJson(String name) throws IOException {
        return TestJson.parse(Files.readString(corpusDir().resolve(name), StandardCharsets.UTF_8));
    }

    @SuppressWarnings("unchecked")
    static List<Map<String, Object>> rows(String name) throws IOException {
        return (List<Map<String, Object>>) (List<?>) readJson(name);
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> map(Object value) {
        check(value instanceof Map, "expected an object but got " + value);
        return (Map<String, Object>) value;
    }

    @SuppressWarnings("unchecked")
    static List<Object> list(Object value) {
        check(value instanceof List, "expected an array but got " + value);
        return (List<Object>) value;
    }

    static String text(Object value) {
        check(value instanceof String, "expected a string but got " + value);
        return (String) value;
    }

    static List<String> texts(Object value) {
        List<String> out = new ArrayList<>();
        for (Object item : list(value)) {
            out.add(text(item));
        }
        return out;
    }

    static DigestScope scopeOf(Map<String, Object> scope) {
        if (scope.size() == 1 && scope.containsKey("within_runtime")) {
            return new DigestScope.WithinRuntime(text(scope.get("within_runtime")));
        }
        if (scope.size() == 1 && scope.containsKey("cross_language")) {
            return new DigestScope.CrossLanguage(text(scope.get("cross_language")));
        }
        throw new AssertionError("unknown digest scope " + scope);
    }

    static Certificate<String, String, String, String, String, String> certificateOf(Map<String, Object> object) {
        Map<String, Object> source = map(object.get("source"));
        Map<String, ProjectionDigest> digests = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : map(object.get("digests")).entrySet()) {
            Map<String, Object> digest = map(entry.getValue());
            digests.put(entry.getKey(), new ProjectionDigest(text(digest.get("digest")), scopeOf(map(digest.get("scope")))));
        }
        return new Certificate<>(
                text(object.get("rule_revision")),
                new SourceRef<>(text(source.get("identity")), text(source.get("revision"))),
                text(object.get("coordinate")),
                digests,
                texts(object.get("residuals")),
                text(object.get("observations")),
                text(object.get("evidence")));
    }

    static Expected<String, String, String, String, String> expectedOf(Map<String, Object> object) {
        Map<String, Object> source = map(object.get("source"));
        return new Expected<>(
                text(object.get("rule_revision")),
                new SourceRef<>(text(source.get("identity")), text(source.get("revision"))),
                text(object.get("coordinate")),
                text(object.get("observations")),
                texts(object.get("residuals")));
    }

    static String canonical(Object value) {
        if (value == null) {
            return "null";
        }
        if (value instanceof Boolean || value instanceof Number) {
            return value.toString();
        }
        if (value instanceof String text) {
            return ComparisonEvidence.canonicalString(text);
        }
        if (value instanceof List<?> items) {
            StringBuilder out = new StringBuilder("[");
            for (int i = 0; i < items.size(); i++) {
                if (i > 0) {
                    out.append(',');
                }
                out.append(canonical(items.get(i)));
            }
            return out.append(']').toString();
        }
        if (value instanceof Map<?, ?> fields) {
            List<String> keys = fields.keySet().stream().map(key -> (String) key).sorted(UTF8_BYTES).toList();
            StringBuilder out = new StringBuilder("{");
            for (int i = 0; i < keys.size(); i++) {
                if (i > 0) {
                    out.append(',');
                }
                out.append(ComparisonEvidence.canonicalString(keys.get(i))).append(':')
                        .append(canonical(fields.get(keys.get(i))));
            }
            return out.append('}').toString();
        }
        throw new AssertionError("unsupported JSON value " + value);
    }

    static Map<String, Object> outcome(String name, Certificate<String, String, String, String, String, String> certificate,
            AdmissionChecks<String> checks, boolean accepted) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("name", name);
        out.put("accepted", accepted);
        out.put("conditions", conditions(checks));
        out.put("residuals", certificate.residuals().values().stream().sorted(UTF8_BYTES).toList());
        return out;
    }

    static Map<String, Object> conditions(AdmissionChecks<String> checks) {
        Map<String, Object> out = new LinkedHashMap<>();
        for (Condition condition : Condition.values()) {
            out.put(condition.name().toLowerCase(Locale.ROOT), conditionJson(checks, condition));
        }
        return out;
    }

    static Map<String, Object> conditionJson(AdmissionChecks<String> checks, Condition condition) {
        Map<String, Object> out = new LinkedHashMap<>();
        Status<String> status = checks.statusAt(condition);
        out.put("status", switch (status) {
            case Status.Matched<String> matched -> "matched";
            case Status.Mismatched<String> mismatched -> "mismatched";
            case Status.UncheckedByDecode<String> unchecked -> "unchecked";
            case Status.UncheckedBySource<String> unchecked -> "unchecked";
        });
        if (status instanceof Status.UncheckedByDecode<String>) {
            out.put("prerequisite", "decode");
        }
        if (status instanceof Status.UncheckedBySource<String>) {
            out.put("prerequisite", "source");
        }
        ConditionFailure<String> failure = failureOf(checks, condition);
        if (failure != null) {
            out.put("failure", failureJson(failure));
        }
        if (condition == Condition.DIGEST && checks.decode() instanceof Prerequisite.Established<ConditionFailure<String>, DigestChecks>(
                var digests)) {
            Map<String, Object> projections = new LinkedHashMap<>();
            digests.results().forEach((name, result) -> projections.put(name, projectionJson(result)));
            out.put("projections", projections);
        }
        return out;
    }

    static ConditionFailure<String> failureOf(AdmissionChecks<String> checks, Condition condition) {
        return switch (condition) {
            case DECODE, DIGEST -> decodeFailure(checks);
            case SOURCE -> sourceFailure(checks);
            case COORDINATE -> childFailure(checks, SourceChecks::coordinate);
            case OBSERVATIONS -> childFailure(checks, SourceChecks::observations);
            case RESIDUAL -> childFailure(checks, SourceChecks::residual);
        };
    }

    static ConditionFailure<String> decodeFailure(AdmissionChecks<String> checks) {
        return checks.decode() instanceof Prerequisite.Failed<ConditionFailure<String>, DigestChecks>(var failure)
                ? failure : null;
    }

    static ConditionFailure<String> sourceFailure(AdmissionChecks<String> checks) {
        return checks.source() instanceof Prerequisite.Failed<ConditionFailure<String>, SourceChecks<String>>(var failure)
                ? failure : null;
    }

    static ConditionFailure<String> childFailure(AdmissionChecks<String> checks,
            Function<SourceChecks<String>, CheckResult<ConditionFailure<String>>> select) {
        if (checks.source() instanceof Prerequisite.Failed<ConditionFailure<String>, SourceChecks<String>>(var failure)) {
            return failure;
        }
        if (checks.source() instanceof Prerequisite.Established<ConditionFailure<String>, SourceChecks<String>>(var children)
                && select.apply(children) instanceof CheckResult.Mismatched<ConditionFailure<String>>(var failure)) {
            return failure;
        }
        return null;
    }

    static Map<String, Object> failureJson(ConditionFailure<String> failure) {
        Map<String, Object> origin = new LinkedHashMap<>();
        origin.put("rule_revision", failure.origin().ruleRevision());
        origin.put("source_identity", failure.origin().sourceIdentity());
        origin.put("source_revision", failure.origin().sourceRevision());
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("operation", failure.operation());
        out.put("origin", origin);
        return out;
    }

    static Map<String, Object> projectionJson(ProjectionResult result) {
        Map<String, Object> out = new LinkedHashMap<>();
        switch (result) {
            case ProjectionResult.Matched matched -> {
                out.put("result", "matched");
                out.put("value", digestJson(matched.value()));
            }
            case ProjectionResult.CertificateOnly certificateOnly -> {
                out.put("result", "certificate_only");
                out.put("actual", digestJson(certificateOnly.actual()));
            }
            case ProjectionResult.RecomputedOnly recomputedOnly -> {
                out.put("result", "recomputed_only");
                out.put("expected", digestJson(recomputedOnly.expected()));
            }
            case ProjectionResult.Different different -> {
                out.put("result", "different");
                out.put("expected", digestJson(different.expected()));
                out.put("actual", digestJson(different.actual()));
            }
        }
        return out;
    }

    static Map<String, Object> digestJson(ProjectionDigest digest) {
        Map<String, Object> scope = new LinkedHashMap<>();
        switch (digest.scope()) {
            case DigestScope.WithinRuntime within -> scope.put("within_runtime", within.payload());
            case DigestScope.CrossLanguage cross -> scope.put("cross_language", cross.payload());
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("digest", digest.digest());
        out.put("scope", scope);
        return out;
    }

    static Map<Condition, String> labels(AdmissionChecks<String> checks) {
        Map<Condition, String> out = new EnumMap<>(Condition.class);
        for (Condition condition : Condition.values()) {
            out.put(condition, switch (checks.statusAt(condition)) {
                case Status.Matched<String> matched -> "matched";
                case Status.Mismatched<String> mismatched -> "mismatched";
                case Status.UncheckedByDecode<String> unchecked -> "unchecked_by_decode";
                case Status.UncheckedBySource<String> unchecked -> "unchecked_by_source";
            });
        }
        return out;
    }

    static Map<Condition, String> expectedLabels(String decode, String source, String digest,
            String coordinate, String observations, String residual) {
        Map<Condition, String> out = new EnumMap<>(Condition.class);
        out.put(Condition.DECODE, decode);
        out.put(Condition.SOURCE, source);
        out.put(Condition.DIGEST, digest);
        out.put(Condition.COORDINATE, coordinate);
        out.put(Condition.OBSERVATIONS, observations);
        out.put(Condition.RESIDUAL, residual);
        return out;
    }

    static void corpusOutcomesEqualLeanOutcomes() throws IOException {
        var table = comparisonTable();
        var cases = rows("cases.json");
        var lean = rows("lean-outcomes.json");
        same(21, cases.size(), "case count");
        same(cases.size(), lean.size(), "lean row count");
        for (int i = 0; i < cases.size(); i++) {
            assertOutcomeEquals(table, cases.get(i), lean.get(i));
        }
    }

    static void residualSetApiCasesEqualLeanOutcomes() throws IOException {
        var table = comparisonTable();
        var cases = rows("residual-set-api-cases-v1.json");
        var lean = rows("residual-set-api-outcomes-v1.json");
        same(2, cases.size(), "versioned API case count");
        same(cases.size(), lean.size(), "versioned API Lean row count");
        for (int i = 0; i < cases.size(); i++) {
            assertOutcomeEquals(table, cases.get(i), lean.get(i));
        }
        check(Boolean.TRUE.equals(lean.get(0).get("accepted")), "order and duplicates are accepted");
        check(Boolean.FALSE.equals(lean.get(1).get("accepted")), "different membership is rejected");
    }

    static void assertOutcomeEquals(RuleTable<String, String, String, String, String> table,
            Map<String, Object> row, Map<String, Object> lean) {
        String name = text(row.get("name"));
        same(text(lean.get("name")), name, "row name");
        var certificate = certificateOf(map(row.get("certificate")));
        var expected = expectedOf(map(row.get("expected")));
        String provenance = text(row.get("provenance"));
        var result = Checked.admit(table, certificate, expected, provenance);
        boolean accepted = result instanceof Result.Accepted<?, ?>;
        AdmissionChecks<String> checks = accepted
                ? checksOf(table, certificate, expected, provenance)
                : rejectedOf(result).checks();
        same(accepted, checks.allMatched(), "acceptance of " + name);
        same(canonical(lean), canonical(outcome(name, certificate, checks, accepted)), "outcome of " + name);
    }

    static void corpusAcceptedRowsReturnCertificateAndRecomputed() throws IOException {
        var table = comparisonTable();
        int accepted = 0;
        for (Map<String, Object> row : rows("cases.json")) {
            var result = Checked.admit(table, certificateOf(map(row.get("certificate"))), expectedOf(map(row.get("expected"))),
                    text(row.get("provenance")));
            if (!(result instanceof Result.Accepted<?, ?>)) {
                continue;
            }
            accepted++;
            var checked = acceptedOf(result);
            var expectedCertificate = certificateOf(map(row.get("certificate")));
            same(expectedCertificate, checked.certificate(), "certificate of " + row.get("name"));
            var recomputed = COMPARISON.recompute(expectedCertificate.source(), expectedCertificate.coordinate(),
                    expectedCertificate.observations(), expectedCertificate.evidence());
            same(recomputed, checked.recomputed(), "recomputed digests of " + row.get("name"));
            same(expectedCertificate.digests(), checked.recomputed(), "digests equal recomputation of " + row.get("name"));
        }
        same(2, accepted, "accepted row count");
    }

    static void corpusRejectedRowsKeepProvenanceAndOrigin() throws IOException {
        var table = comparisonTable();
        int rejected = 0;
        for (Map<String, Object> row : rows("cases.json")) {
            var result = Checked.admit(table, certificateOf(map(row.get("certificate"))), expectedOf(map(row.get("expected"))),
                    text(row.get("provenance")));
            if (result instanceof Result.Accepted<?, ?>) {
                continue;
            }
            rejected++;
            var mismatch = rejectedOf(result);
            same(text(row.get("provenance")), mismatch.provenance(), "provenance of " + row.get("name"));
            var certificate = certificateOf(map(row.get("certificate")));
            same(certificate.ruleRevision(), mismatch.origin().ruleRevision(), "origin rule of " + row.get("name"));
            same(certificate.source().identity(), mismatch.origin().sourceIdentity(), "origin identity of " + row.get("name"));
            same(certificate.source().revision(), mismatch.origin().sourceRevision(), "origin revision of " + row.get("name"));
            check(!mismatch.describe().isEmpty(), "description is present");
        }
        same(19, rejected, "rejected row count");
    }

    static void jsonReaderDecodesEscapes() {
        Object value = TestJson.parse("[\"\\u0000\\u001f/\\\"\\\\\\n\\t\\b\\f\\r\", \"\u65e5\u672c\u8a9e\", \"\\ud83d\\ude00\"]");
        var items = list(value);
        same("\u0000\u001f/\"\\\n\t\b\f\r", items.get(0), "escapes");
        same("\u65e5\u672c\u8a9e", items.get(1), "raw utf-8 text");
        same("\uD83D\uDE00", items.get(2), "surrogate pair escape");
    }

    static void canonicalStringEscapes() {
        same("\"\\\"\\\\\\b\\f\\n\\r\\t\\u0000\\u0001\\u001f/\u007f\u65e5\u672c\u8a9e\"",
                ComparisonEvidence.canonicalString("\"\\\b\f\n\r\t\u0000\u0001\u001f/\u007f\u65e5\u672c\u8a9e"),
                "canonical escapes");
    }

    static void canonicalKeysFollowUtf8Bytes() {
        var fields = new LinkedHashMap<String, Object>();
        fields.put(GRINNING_FACE, 2);
        fields.put(FULLWIDTH_TILDE, 1);
        same("{\"" + FULLWIDTH_TILDE + "\":1,\"" + GRINNING_FACE + "\":2}", canonical(fields),
                "the fullwidth tilde (EF BD 9E) precedes the emoji (F0 9F 98 80)");
        check(FULLWIDTH_TILDE.compareTo(GRINNING_FACE) > 0,
                "the UTF-16 order would reverse these keys");
    }

    static void decodeFailureLeavesDigestUnchecked() {
        var draft = new Draft();
        draft.ruleRevision = OTHER_REVISION;
        var mismatch = rejectedOf(admit(draft));
        var failure = decodeFailure(mismatch.checks());
        check(failure != null, "decode failed");
        same(REVISION, failure.expected(), "expected revision");
        same(OTHER_REVISION, failure.actual(), "actual revision");
        same(expectedLabels("mismatched", "matched", "unchecked_by_decode", "matched", "matched", "matched"),
                labels(mismatch.checks()), "decode failure statuses");
    }

    static void unknownRuleIsDecodeFailure() {
        var draft = new Draft();
        draft.ruleRevision = "comparison/sha256@9";
        var expected = new Expected<>("comparison/sha256@9", new SourceRef<>("source-alpha", "rev-1"), "coord-a",
                "observations-a", List.of("residual-a", "residual-b"));
        var mismatch = rejectedOf(Checked.admit(comparisonTable(), draft.certificate(), expected, "caller"));
        var failure = decodeFailure(mismatch.checks());
        check(failure != null, "decode failed for an unregistered rule");
        same("rule in table", failure.expected(), "expected of an unregistered rule");
        same("comparison/sha256@9", failure.actual(), "actual revision of an unregistered rule");
        same(Status.UncheckedByDecode.class, mismatch.statusAt(Condition.DIGEST).getClass(),
                "digest is unchecked by the unregistered rule");
    }

    static void eachConditionAloneIsReported() {
        var decode = new Draft();
        decode.ruleRevision = OTHER_REVISION;
        same(expectedLabels("mismatched", "matched", "unchecked_by_decode", "matched", "matched", "matched"),
                labels(checksOfDraft(decode)), "decode alone");

        var source = new Draft();
        source.identity = "source-beta";
        same(expectedLabels("matched", "mismatched", "matched", "unchecked_by_source", "unchecked_by_source",
                "unchecked_by_source"), labels(checksOfDraft(source)), "source alone");

        var coordinate = new Draft();
        coordinate.coordinate = "coord-b";
        same(expectedLabels("matched", "matched", "matched", "mismatched", "matched", "matched"),
                labels(checksOfDraft(coordinate)), "coordinate alone");

        var observations = new Draft();
        observations.observations = "observations-b";
        same(expectedLabels("matched", "matched", "matched", "matched", "mismatched", "matched"),
                labels(checksOfDraft(observations)), "observations alone");

        var digest = new Draft();
        digest.evidence = "evidence-other";
        same(expectedLabels("matched", "matched", "mismatched", "matched", "matched", "matched"),
                labels(checksOfDraft(digest)), "digest alone");

        var residual = new Draft();
        residual.residuals = List.of("residual-c");
        same(expectedLabels("matched", "matched", "matched", "matched", "matched", "mismatched"),
                labels(checksOfDraft(residual)), "residual alone");
    }

    static void failuresHoldTheirOwnCondition() {
        for (Constructor<?> constructor : ConditionFailure.class.getDeclaredConstructors()) {
            check(!Modifier.isPublic(constructor.getModifiers()), "ConditionFailure constructor is not public");
        }
        var decode = new Draft();
        decode.ruleRevision = OTHER_REVISION;
        var unregistered = new Draft();
        unregistered.ruleRevision = "comparison/sha256@9";
        var expectedUnregistered = new Expected<>("comparison/sha256@9", new SourceRef<>("source-alpha", "rev-1"),
                "coord-a", "observations-a", List.of("residual-a", "residual-b"));
        var source = new Draft();
        source.identity = "source-beta";
        var coordinate = new Draft();
        coordinate.coordinate = "coord-b";
        var observations = new Draft();
        observations.observations = "observations-b";
        var residual = new Draft();
        residual.residuals = List.of("residual-c");
        var all = new Draft();
        all.coordinate = "coord-b";
        all.observations = "observations-b";
        all.residuals = List.of("residual-c");

        List<ConditionFailure<String>> extracted = new ArrayList<>();
        extracted.add(decodeFailure(checksOfDraft(decode)));
        extracted.add(decodeFailure(rejectedOf(Checked.admit(comparisonTable(), unregistered.certificate(),
                expectedUnregistered, "caller")).checks()));
        extracted.add(sourceFailure(checksOfDraft(source)));
        for (Draft draft : List.of(coordinate, observations, residual, all)) {
            for (Condition condition : List.of(Condition.COORDINATE, Condition.OBSERVATIONS, Condition.RESIDUAL)) {
                var failure = childFailure(checksOfDraft(draft), switch (condition) {
                    case COORDINATE -> SourceChecks::coordinate;
                    case OBSERVATIONS -> SourceChecks::observations;
                    default -> SourceChecks::residual;
                });
                if (failure != null) {
                    same(condition, failure.condition(), "child failure condition");
                    extracted.add(failure);
                }
            }
        }
        same(Condition.DECODE, extracted.get(0).condition(), "decode mismatch");
        same(Condition.DECODE, extracted.get(1).condition(), "unregistered rule");
        same(Condition.SOURCE, extracted.get(2).condition(), "source failure");
        Map<Condition, ConditionFailure<String>> byCondition = new EnumMap<>(Condition.class);
        for (ConditionFailure<String> failure : extracted) {
            check(failure != null, "failure is present");
            byCondition.putIfAbsent(failure.condition(), failure);
        }
        same(Set.of(Condition.DECODE, Condition.SOURCE, Condition.COORDINATE, Condition.OBSERVATIONS,
                Condition.RESIDUAL), byCondition.keySet(), "conditions held by extracted failures");
        for (var entry : byCondition.entrySet()) {
            same(entry.getKey(), entry.getValue().condition(), "failure in a separate collection");
        }
    }

    static void simultaneousRootFailuresAreAllReported() {
        var draft = new Draft();
        draft.ruleRevision = OTHER_REVISION;
        draft.identity = "source-beta";
        draft.coordinate = "coord-b";
        draft.evidence = "evidence-other";
        var mismatch = rejectedOf(admit(draft));
        same(expectedLabels("mismatched", "mismatched", "unchecked_by_decode", "unchecked_by_source",
                "unchecked_by_source", "unchecked_by_source"), labels(mismatch.checks()), "both roots failing");
    }

    static void simultaneousChildrenFailuresAreAllReported() {
        var draft = new Draft();
        draft.coordinate = "coord-b";
        draft.observations = "observations-b";
        draft.residuals = List.of("residual-c");
        var mismatch = rejectedOf(admit(draft));
        same(expectedLabels("matched", "matched", "matched", "mismatched", "mismatched", "mismatched"),
                labels(mismatch.checks()), "three independent children");
        same(3, mismatch.checks().source() instanceof Prerequisite.Established<ConditionFailure<String>, SourceChecks<String>>(
                var children) ? countMismatched(children) : -1, "each child keeps its own failure");
    }

    static int countMismatched(SourceChecks<String> children) {
        int count = 0;
        for (CheckResult<ConditionFailure<String>> check : List.of(children.coordinate(), children.observations(),
                children.residual())) {
            if (!check.isMatched()) {
                count++;
            }
        }
        return count;
    }

    static void sourceFailureLeavesChildrenUnchecked() {
        var draft = new Draft();
        draft.identity = "source-beta";
        draft.coordinate = "coord-b";
        var mismatch = rejectedOf(admit(draft));
        var sourceFailure = sourceFailure(mismatch.checks());
        check(sourceFailure != null, "source failed");
        same(sourceFailure, failureOf(mismatch.checks(), Condition.COORDINATE), "coordinate is unchecked by the source failure");
        same(Status.UncheckedBySource.class, mismatch.statusAt(Condition.RESIDUAL).getClass(),
                "residual is unchecked by the source");
        check(mismatch.statusAt(Condition.COORDINATE) instanceof Status.UncheckedBySource<String>(var failure)
                && failure.equals(sourceFailure), "the unchecked status carries the source failure");
    }

    static void digestIsCheckedIndependentlyOfSource() {
        var draft = new Draft();
        draft.identity = "source-beta";
        draft.evidence = "evidence-other";
        var mismatch = rejectedOf(admit(draft));
        same(expectedLabels("matched", "mismatched", "mismatched", "unchecked_by_source", "unchecked_by_source",
                "unchecked_by_source"), labels(mismatch.checks()), "digest is checked beside a source failure");
    }

    static void digestNamesAreClassifiedByKey() {
        var certificateOnly = new ProjectionDigest("1".repeat(64), CROSS);
        var recomputedOnly = new ProjectionDigest("2".repeat(64), CROSS);
        var shared = new ProjectionDigest("3".repeat(64), CROSS);
        var sharedWithinRuntime = new ProjectionDigest("3".repeat(64), new DigestScope.WithinRuntime("sha256"));
        var results = DigestChecks.check(
                Map.of("beta", shared, "delta", recomputedOnly, "gamma", shared),
                Map.of("alpha", certificateOnly, "beta", sharedWithinRuntime, "gamma", shared)).results();
        same(new ProjectionResult.CertificateOnly(certificateOnly), results.get("alpha"), "certificate only");
        same(new ProjectionResult.Different(shared, sharedWithinRuntime), results.get("beta"),
                "same value with a different scope differs");
        same(new ProjectionResult.RecomputedOnly(recomputedOnly), results.get("delta"), "recomputed only");
        same(new ProjectionResult.Matched(shared), results.get("gamma"), "same name, value and scope match");
        same(List.of("alpha", "beta", "delta", "gamma"), List.copyOf(results.keySet()), "keys in UTF-8 order");
    }

    static void digestScopeKindAndPayloadAreCompared() {
        var value = "4".repeat(64);
        var recomputed = Map.of("evidence", new ProjectionDigest(value, CROSS));
        for (DigestScope variant : List.of(new DigestScope.WithinRuntime("sha256"),
                new DigestScope.CrossLanguage("sha512"))) {
            var actual = Map.of("evidence", new ProjectionDigest(value, variant));
            same(new ProjectionResult.Different(new ProjectionDigest(value, CROSS), new ProjectionDigest(value, variant)),
                    DigestChecks.check(recomputed, actual).results().get("evidence"), "scope " + variant);
        }
        check(!new DigestScope.WithinRuntime("sha256").equals(new DigestScope.CrossLanguage("sha256")),
                "kind alone distinguishes scopes");
    }

    static void digestInsertionOrderDoesNotChangeOutcome() {
        var table = built(RuleTable.of(List.of(entry(REVISION, (source, coordinate, observations, evidence) -> {
            var out = new LinkedHashMap<String, ProjectionDigest>();
            out.put("alpha", new ProjectionDigest(ComparisonEvidence.digest(evidence), CROSS));
            out.put("beta", new ProjectionDigest("2".repeat(64), CROSS));
            return out;
        }))));
        var forward = new LinkedHashMap<String, ProjectionDigest>();
        forward.put("alpha", new ProjectionDigest(ComparisonEvidence.digest("evidence-plain"), CROSS));
        forward.put("beta", new ProjectionDigest("2".repeat(64), CROSS));
        var reverse = new LinkedHashMap<String, ProjectionDigest>();
        reverse.put("beta", new ProjectionDigest("2".repeat(64), CROSS));
        reverse.put("alpha", new ProjectionDigest(ComparisonEvidence.digest("evidence-plain"), CROSS));
        var source = new SourceRef<String, String>("source-alpha", "rev-1");
        var residuals = List.of("residual-a", "residual-b");
        var expected = new Expected<>(REVISION, source, "coord-a", "observations-a", residuals);
        var accepted = acceptedOf(Checked.admit(table,
                new Certificate<>(REVISION, source, "coord-a", forward, residuals, "observations-a", "evidence-plain"),
                expected, "caller"));
        var reversed = acceptedOf(Checked.admit(table,
                new Certificate<>(REVISION, source, "coord-a", reverse, residuals, "observations-a", "evidence-plain"),
                expected, "caller"));
        same(accepted.certificate(), reversed.certificate(), "certificates equal in any insertion order");
        same(accepted.recomputed(), reversed.recomputed(), "recomputed digests equal in any insertion order");
        same(List.copyOf(accepted.recomputed().keySet()), List.copyOf(reversed.recomputed().keySet()),
                "checked keys follow the same order");
    }

    static void renamingOneKeyIsIsolated() {
        var evidence = new ProjectionDigest("5".repeat(64), CROSS);
        var other = new ProjectionDigest("6".repeat(64), CROSS);
        var before = DigestChecks.check(Map.of("evidence", evidence, "other", other),
                Map.of("evidence", evidence, "other", other)).results();
        var after = DigestChecks.check(Map.of("evidence", evidence, "other", other),
                Map.of("evidence", evidence, "renamed", other)).results();
        same(new ProjectionResult.Matched(evidence), after.get("evidence"), "unrenamed name keeps its result");
        same(before.get("evidence"), after.get("evidence"), "unrenamed name is unchanged");
        same(new ProjectionResult.RecomputedOnly(other), after.get("other"), "the old name is recomputed only");
        same(new ProjectionResult.CertificateOnly(other), after.get("renamed"), "the new name is certificate only");
    }

    static void digestChecksIterateInUtf8ByteOrder() {
        var value = new ProjectionDigest("7".repeat(64), CROSS);
        var results = DigestChecks.check(Map.of(GRINNING_FACE, value, FULLWIDTH_TILDE, value),
                Map.of(GRINNING_FACE, value, FULLWIDTH_TILDE, value)).results();
        var keys = List.copyOf(results.keySet());
        same(List.of(FULLWIDTH_TILDE, GRINNING_FACE), keys, "UTF-8 byte order of the keys");
        same(keys.stream().sorted(UTF8_BYTES).toList(), keys, "the order is the byte order of the oracle");
    }

    static void residualMembershipIgnoresOrderAndDuplicates() {
        var draft = new Draft();
        draft.residuals = List.of("residual-b", "residual-a", "residual-a");
        same(expectedLabels("matched", "matched", "matched", "matched", "matched", "matched"),
                labels(checksOfDraft(draft)), "order and duplicates");
        acceptedOf(admit(draft));
    }

    static void residualMembershipIsCompared() {
        var draft = new Draft();
        draft.residuals = List.of("residual-a", "residual-c");
        same(Status.Mismatched.class, checksOfDraft(draft).statusAt(Condition.RESIDUAL).getClass(),
                "different residual membership");
    }

    static void duplicateRuleIsATypedFailureAtConstruction() {
        var duplicated = RuleTable.of(List.of(entry("rule@2", COMPARISON), entry("rule@1", COMPARISON),
                entry("rule@2", COMPARISON), entry("rule@1", COMPARISON)));
        same(new Result.Rejected<>(new DuplicateRule("rule@2")), duplicated,
                "the first reappearing revision is the typed failure");
        check(RuleTable.of(List.of(entry("rule@1", COMPARISON))) instanceof Result.Accepted<?, ?>,
                "distinct revisions build a table");
    }

    static void tableIsIndependentFromInputList() {
        var entries = new ArrayList<RuleEntry<String, String, String, String, String>>();
        entries.add(entry(REVISION, COMPARISON));
        var table = built(RuleTable.of(entries));
        Rule<String, String, String, String, String> replacement = (source, coordinate, observations, evidence) ->
                Map.of("evidence", new ProjectionDigest("f".repeat(64), CROSS));
        entries.set(0, entry(REVISION, replacement));
        entries.add(entry(OTHER_REVISION, COMPARISON));
        var accepted = acceptedOf(Checked.admit(table, new Draft().certificate(), baseExpected(), "caller"));
        same(digestsOf("evidence-plain"), accepted.recomputed(), "replacement is not visible");
        entries.clear();
        acceptedOf(Checked.admit(table, new Draft().certificate(), baseExpected(), "caller"));
        var draft = new Draft();
        draft.ruleRevision = OTHER_REVISION;
        var expected = new Expected<>(OTHER_REVISION, new SourceRef<>("source-alpha", "rev-1"), "coord-a", "observations-a",
                List.of("residual-a", "residual-b"));
        var mismatch = rejectedOf(Checked.admit(table, draft.certificate(), expected, "caller"));
        var failure = decodeFailure(mismatch.checks());
        check(failure != null, "inserted revision is not in the table");
        same("rule in table", failure.expected(), "table expectation");
    }

    static void tableOrderDoesNotChangeSelectedRule() {
        Rule<String, String, String, String, String> ruleA = (source, coordinate, observations, evidence) ->
                Map.of("evidence", new ProjectionDigest(ComparisonEvidence.digest(evidence), CROSS));
        Rule<String, String, String, String, String> ruleB = (source, coordinate, observations, evidence) ->
                Map.of("evidence", new ProjectionDigest(ComparisonEvidence.digest(evidence + "#b"), CROSS));
        List<String> revisions = List.of("comparison/sha256@1", "comparison/sha256@2");
        var forward = built(RuleTable.of(List.of(entry(revisions.get(0), ruleA), entry(revisions.get(1), ruleB))));
        var reversed = built(RuleTable.of(List.of(entry(revisions.get(1), ruleB), entry(revisions.get(0), ruleA))));
        List<RuleTable<String, String, String, String, String>> tables = List.of(forward, reversed);
        var source = new SourceRef<String, String>("source-alpha", "rev-1");
        List<String> residuals = List.of("residual-a", "residual-b");
        check(!ruleA.recompute(source, "coord-a", "observations-a", "evidence-plain")
                .equals(ruleB.recompute(source, "coord-a", "observations-a", "evidence-plain")),
                "the two rules produce different digests");
        List<Rule<String, String, String, String, String>> rules = List.of(ruleA, ruleB);
        for (int index = 0; index < revisions.size(); index++) {
            String revision = revisions.get(index);
            var expected = new Expected<>(revision, source, "coord-a", "observations-a", residuals);
            var digests = rules.get(index).recompute(source, "coord-a", "observations-a", "evidence-plain");
            var certificate = new Certificate<>(revision, source, "coord-a", digests, residuals,
                    "observations-a", "evidence-plain");
            for (var table : tables) {
                var checked = acceptedOf(Checked.admit(table, certificate, expected, "caller"));
                same(digests, checked.recomputed(), "recomputed digests of " + revision);
            }
            var otherDigests = rules.get(1 - index).recompute(source, "coord-a", "observations-a", "evidence-plain");
            var wrong = new Certificate<>(revision, source, "coord-a", otherDigests, residuals,
                    "observations-a", "evidence-plain");
            for (var table : tables) {
                var mismatch = rejectedOf(Checked.admit(table, wrong, expected, "caller"));
                same(Status.Mismatched.class, mismatch.statusAt(Condition.DIGEST).getClass(),
                        "other rule digests under " + revision);
            }
        }
    }

    static void certificateMapsAreDetachedFromInput() {
        var digests = new HashMap<String, ProjectionDigest>();
        digests.put("evidence", new ProjectionDigest("0".repeat(64), CROSS));
        var residuals = new ArrayList<String>();
        residuals.add("residual-a");
        var source = new SourceRef<String, String>("source-alpha", "rev-1");
        var certificate = new Certificate<String, String, String, String, String, String>(
                REVISION, source, "coord-a", digests, residuals, "observations-a", "evidence-plain");
        digests.clear();
        residuals.add("residual-b");
        same(1, certificate.digests().size(), "digest map is copied");
        same(ResidualSet.of(List.of("residual-a")), certificate.residuals(), "residual set is copied");
        var expectedResiduals = new ArrayList<String>(List.of("residual-a"));
        var expected = new Expected<>(REVISION, source, "coord-a", "observations-a", expectedResiduals);
        expectedResiduals.clear();
        same(ResidualSet.of(List.of("residual-a")), expected.residuals(), "expected residual set is copied");
        var recomputedSource = new HashMap<String, ProjectionDigest>();
        recomputedSource.put("evidence", new ProjectionDigest(ComparisonEvidence.digest("evidence-plain"), CROSS));
        var checked = acceptedOf(Checked.admit(built(RuleTable.of(List.of(entry(REVISION,
                (s, c, o, e) -> recomputedSource)))), new Certificate<>(REVISION, source, "coord-a",
                recomputedSource, List.of("residual-a"), "observations-a", "evidence-plain"),
                new Expected<>(REVISION, source, "coord-a", "observations-a", List.of("residual-a")), "caller"));
        recomputedSource.clear();
        same(1, checked.recomputed().size(), "the rule output is copied");
    }

    static void provenanceIsReturnedUnchanged() {
        Object provenance = new Object();
        var draft = new Draft();
        draft.identity = "source-beta";
        var mismatch = rejectedOf(Checked.admit(comparisonTable(), draft.certificate(), baseExpected(), provenance));
        check(mismatch.provenance() == provenance, "the same provenance object is returned");
        check(mismatch.checks().provenance() == provenance, "the checks keep the same provenance object");
    }

    static void checkedValueExposesAdmittedParts() {
        var draft = new Draft();
        var checked = acceptedOf(admit(draft));
        same(draft.certificate(), checked.certificate(), "certificate");
        same(baseExpected(), checked.expected(), "expected");
        same(new SourceRef<>("source-alpha", "rev-1"), checked.source(), "source");
        same(digestsOf("evidence-plain"), checked.recomputed(), "recomputed digests");
        try {
            checked.recomputed().put("extra", new ProjectionDigest("0".repeat(64), CROSS));
        } catch (UnsupportedOperationException expectedError) {
            return;
        }
        throw new AssertionError("recomputed digests are mutable");
    }

    static void checkReturnsChecksOnAcceptance() {
        var draft = new Draft();
        var checks = Checked.check(comparisonTable(), draft.certificate(), baseExpected(), "caller");
        check(checks.allMatched(), "all conditions matched");
        same(expectedLabels("matched", "matched", "matched", "matched", "matched", "matched"), labels(checks),
                "all six conditions are matched");
        same("caller", checks.provenance(), "provenance");
    }

    static void recordValuesCompareByComponents() {
        var first = new SourceRef<>("a", 1);
        check(first.equals(new SourceRef<>("a", 1)) && first.hashCode() == new SourceRef<>("a", 1).hashCode(),
                "source refs compare by components");
        var digest = new ProjectionDigest("d", new DigestScope.CrossLanguage("s"));
        check(digest.equals(new ProjectionDigest("d", new DigestScope.CrossLanguage("s")))
                        && digest.hashCode() == new ProjectionDigest("d", new DigestScope.CrossLanguage("s")).hashCode(),
                "projection digests compare by components");
        check(!digest.equals(new ProjectionDigest("d", new DigestScope.WithinRuntime("s"))),
                "scope kind participates in equality");
        var certificate = new Draft().certificate();
        check(certificate.equals(new Draft().certificate()), "certificates compare by components");
        var reordered = new Draft();
        reordered.residuals = List.of("residual-b", "residual-a");
        check(certificate.equals(reordered.certificate()), "residual membership determines equality");
        check(baseExpected().equals(baseExpected()), "expected values compare by components");
    }

    static void mismatchDescriptionNamesFailingConditions() {
        var draft = new Draft();
        draft.residuals = List.of("residual-c");
        var mismatch = rejectedOf(admit(draft));
        same("admit failed (rule comparison/sha256@1, source source-alpha@rev-1): "
                        + "residual expected [residual-a, residual-b], actual [residual-c]",
                mismatch.describe(), "description");
    }

    static void mismatchRejectsFullyMatchedAdmission() {
        var accepted = checksOfDraft(new Draft());
        check(accepted.allMatched(), "the fixture is fully matched");
        try {
            Mismatch.of(accepted);
        } catch (IllegalArgumentException expectedError) {
            return;
        }
        throw new AssertionError("a fully matched admission was accepted as a mismatch");
    }

    static void publicApiBoundary() {
        check(Modifier.isFinal(Checked.class.getModifiers()), "Checked is final");
        check(Modifier.isFinal(Mismatch.class.getModifiers()), "Mismatch is final");
        for (Constructor<?> constructor : Checked.class.getDeclaredConstructors()) {
            check(!Modifier.isPublic(constructor.getModifiers()), "Checked constructor is not public");
        }
        for (Constructor<?> constructor : Mismatch.class.getDeclaredConstructors()) {
            check(!Modifier.isPublic(constructor.getModifiers()), "Mismatch constructor is not public");
        }
        for (Constructor<?> constructor : RuleTable.class.getDeclaredConstructors()) {
            check(!Modifier.isPublic(constructor.getModifiers()), "RuleTable constructor is not public");
        }
        same(Set.of("admit", "certificate", "check", "expected", "recomputed", "source"), publicMethodNames(Checked.class),
                "Checked public methods");
        same(Set.of("checks", "describe", "origin", "provenance", "statusAt"), publicMethodNames(Mismatch.class),
                "Mismatch public methods");
        same(Set.of("of"), publicMethodNames(RuleTable.class), "RuleTable public methods");
        check(Result.class.isSealed(), "Result is sealed");
        same(Set.of("Accepted", "Rejected"), Arrays.stream(Result.class.getPermittedSubclasses())
                .map(Class::getSimpleName).collect(Collectors.toSet()), "Result permits");
        check(DigestScope.class.isSealed(), "DigestScope is sealed");
        same(Set.of("WithinRuntime", "CrossLanguage"), Arrays.stream(DigestScope.class.getPermittedSubclasses())
                .map(Class::getSimpleName).collect(Collectors.toSet()), "DigestScope permits");
        same(Set.of("Matched", "Mismatched", "UncheckedByDecode", "UncheckedBySource"),
                Arrays.stream(Status.class.getPermittedSubclasses()).map(Class::getSimpleName).collect(Collectors.toSet()),
                "Status permits");
        same(Set.of("Failed", "Established"), Arrays.stream(Prerequisite.class.getPermittedSubclasses())
                .map(Class::getSimpleName).collect(Collectors.toSet()), "Prerequisite permits");
        same(Set.of("Matched", "Mismatched"), Arrays.stream(CheckResult.class.getPermittedSubclasses())
                .map(Class::getSimpleName).collect(Collectors.toSet()), "CheckResult permits");
        same(Set.of("Matched", "CertificateOnly", "RecomputedOnly", "Different"),
                Arrays.stream(ProjectionResult.class.getPermittedSubclasses()).map(Class::getSimpleName)
                        .collect(Collectors.toSet()), "ProjectionResult permits");
        same(List.of("DECODE", "SOURCE", "COORDINATE", "OBSERVATIONS", "DIGEST", "RESIDUAL"),
                Arrays.stream(Condition.values()).map(Enum::name).toList(), "condition order");
        same(List.of("ruleRevision", "source", "coordinate", "digests", "residuals", "observations", "evidence"),
                Arrays.stream(Certificate.class.getRecordComponents()).map(component -> component.getName()).toList(),
                "certificate components");
        same(List.of("digest", "scope"),
                Arrays.stream(ProjectionDigest.class.getRecordComponents()).map(component -> component.getName()).toList(),
                "projection digest components");
        same(List.of("origin", "provenance", "decode", "source"),
                Arrays.stream(AdmissionChecks.class.getRecordComponents()).map(component -> component.getName()).toList(),
                "admission checks components");
        check(Modifier.isFinal(ConditionFailure.class.getModifiers()), "ConditionFailure is final");
        same(Set.of("condition", "operation", "expected", "actual", "origin", "provenance"),
                publicMethodNames(ConditionFailure.class).stream()
                        .filter(name -> !Set.of("equals", "hashCode", "toString").contains(name))
                        .collect(Collectors.toSet()),
                "condition failure accessors");
    }

    static Set<String> publicMethodNames(Class<?> type) {
        return Arrays.stream(type.getDeclaredMethods())
                .filter(method -> Modifier.isPublic(method.getModifiers()))
                .map(Method::getName)
                .collect(Collectors.toSet());
    }

    static RefinementOutcome<String, String, String> resolved(String value) {
        return new RefinementOutcome.Resolved<>(value);
    }

    static RefinementOutcome<String, String, String> residual(String value, List<String> residuals) {
        return new RefinementOutcome.Residual<>(value, residuals);
    }

    static RefinementOutcome<String, String, String> stopped(String value, List<String> residuals, String cause) {
        return new RefinementOutcome.Stopped<>(value, residuals, cause);
    }

    static void refinementOutcomeCasesHoldTheirParts() {
        var outcomes = List.of(resolved("value"), residual("value", List.of("residual-a", "residual-b")),
                stopped("value", List.of("residual-a"), "budget"));
        for (var outcome : outcomes) {
            same("value", outcome.value(), "value");
        }
        if (!(outcomes.get(1) instanceof RefinementOutcome.Residual<String, String, String>(var value, var residuals))) {
            throw new AssertionError("expected a residual outcome");
        }
        same(List.of("residual-a", "residual-b"), residuals.values(), "residual values");
        if (!(outcomes.get(2) instanceof RefinementOutcome.Stopped<String, String, String>(var stoppedValue, var stoppedResiduals, var cause))) {
            throw new AssertionError("expected a stopped outcome");
        }
        same(ResidualSet.of(List.of("residual-a")), stoppedResiduals, "stopped residuals");
        same("budget", cause, "cause");
        check(RefinementOutcome.class.isSealed(), "RefinementOutcome is sealed");
        same(Set.of("Resolved", "Residual", "Stopped"), Arrays.stream(RefinementOutcome.class.getPermittedSubclasses())
                .map(Class::getSimpleName).collect(Collectors.toSet()), "RefinementOutcome permits");
    }

    static void refinementOutcomeEqualPartsAreEqual() {
        same(resolved("value"), resolved("value"), "resolved");
        same(residual("value", List.of("residual-a")), residual("value", List.of("residual-a")), "residual");
        same(stopped("value", List.of("residual-a"), "budget"), stopped("value", List.of("residual-a"), "budget"),
                "stopped");
        same(residual("value", List.of("residual-a")).hashCode(), residual("value", List.of("residual-a")).hashCode(),
                "residual hash");
    }

    static void refinementOutcomeIgnoresResidualOrder() {
        var reordered = residual("value", List.of("residual-b", "residual-a", "residual-a"));
        var plain = residual("value", List.of("residual-a", "residual-b"));
        same(plain, reordered, "residual order and duplicates");
        same(plain.hashCode(), reordered.hashCode(), "residual order hash");
        same(stopped("value", List.of("residual-a", "residual-b"), "budget"),
                new RefinementOutcome.Stopped<String, String, String>("value",
                        ResidualSet.of(List.of("residual-b", "residual-a")), "budget"),
                "stopped residual order");
    }

    static void refinementOutcomeDifferentPartsAreNotEqual() {
        check(!residual("value", List.of("residual-a", "residual-b"))
                .equals(residual("value", List.of("residual-a", "residual-c"))), "different member");
        check(!residual("value", List.of("residual-a"))
                .equals(residual("value", List.of("residual-a", "residual-b"))), "extra member");
        check(!resolved("value").equals(resolved("other")), "resolved value");
        check(!residual("value", List.of("residual-a")).equals(residual("other", List.of("residual-a"))),
                "residual value");
        check(!stopped("value", List.of("residual-a"), "budget").equals(stopped("value", List.of("residual-a"), "timeout")),
                "stopped cause");
    }

    static void refinementOutcomeDifferentCasesAreNotEqual() {
        var residuals = List.of("residual-a");
        check(!resolved("value").equals(residual("value", residuals)), "resolved residual");
        check(!residual("value", residuals).equals(stopped("value", residuals, "budget")), "residual stopped");
        check(!resolved("value").equals(stopped("value", List.of(), "budget")), "resolved stopped");
        check(!residual("value", List.of()).equals(resolved("value")), "empty residual resolved");
    }

    static Path refinementDir() {
        return Path.of("..", "comparison", "refinement-outcome");
    }

    @SuppressWarnings("unchecked")
    static List<Map<String, Object>> refinementRows(String name) throws IOException {
        return (List<Map<String, Object>>) (List<?>) TestJson.parse(
                Files.readString(refinementDir().resolve(name), StandardCharsets.UTF_8));
    }

    static RefinementOutcome<String, String, String> refinementOutcomeOf(Map<String, Object> wire) {
        String value = text(wire.get("value"));
        return switch (text(wire.get("kind"))) {
            case "resolved" -> resolved(value);
            case "residual" -> residual(value, texts(wire.get("residuals")));
            case "stopped" -> stopped(value, texts(wire.get("residuals")), text(wire.get("cause")));
            default -> throw new AssertionError("unknown kind " + wire);
        };
    }

    static List<String> sortedResiduals(ResidualSet<String> residuals) {
        return residuals.values().stream().sorted(UTF8_BYTES).toList();
    }

    static Map<String, Object> refinementOutcomeJson(RefinementOutcome<String, String, String> outcome) {
        var out = new LinkedHashMap<String, Object>();
        switch (outcome) {
            case RefinementOutcome.Resolved<String, String, String> resolved -> {
                out.put("kind", "resolved");
                out.put("value", resolved.value());
            }
            case RefinementOutcome.Residual<String, String, String> residual -> {
                out.put("kind", "residual");
                out.put("value", residual.value());
                out.put("residuals", sortedResiduals(residual.residuals()));
            }
            case RefinementOutcome.Stopped<String, String, String> stopped -> {
                out.put("kind", "stopped");
                out.put("value", stopped.value());
                out.put("residuals", sortedResiduals(stopped.residuals()));
                out.put("cause", stopped.cause());
            }
        }
        return out;
    }

    static void refinementComparisonEqualsLeanOutcomes() throws IOException {
        var cases = refinementRows("cases.json");
        var lean = refinementRows("lean-outcomes.json");
        same(cases.size(), lean.size(), "lean row count");
        var names = new java.util.HashSet<String>();
        var verdicts = new java.util.HashSet<Object>();
        for (int i = 0; i < cases.size(); i++) {
            var row = cases.get(i);
            var expected = lean.get(i);
            var name = text(row.get("name"));
            check(names.add(name), "unique name " + name);
            same(name, expected.get("name"), "row name");
            var left = refinementOutcomeOf(map(row.get("left")));
            var right = refinementOutcomeOf(map(row.get("right")));
            same(expected.get("left"), refinementOutcomeJson(left), name + " left");
            same(expected.get("right"), refinementOutcomeJson(right), name + " right");
            same(expected.get("same"), left.equals(right), name + " same");
            verdicts.add(expected.get("same"));
        }
        same(Set.of(true, false), verdicts, "both verdicts occur");
    }

    static void refinementComparisonInputsAreCanonical() throws IOException {
        for (String name : List.of("cases.json", "lean-outcomes.json")) {
            same(Files.readString(refinementDir().resolve(name), StandardCharsets.UTF_8),
                    canonical(TestJson.parse(Files.readString(refinementDir().resolve(name), StandardCharsets.UTF_8))),
                    name + " is canonical");
        }
    }

    static void refinementComparisonSeparatesReorderingFromSwappedCases() throws IOException {
        var lean = refinementRows("lean-outcomes.json");
        var sameByName = new HashMap<String, Object>();
        for (var row : lean) {
            sameByName.put(text(row.get("name")), row.get("same"));
        }
        same(true, sameByName.get("residual_order_and_duplicates"), "residual reordering");
        same(true, sameByName.get("stopped_order_and_duplicates"), "stopped reordering");
        for (String name : List.of("case_resolved_residual", "case_residual_stopped", "case_resolved_stopped")) {
            same(false, sameByName.get(name), name);
        }
        int disagreements = 0;
        for (var row : refinementRows("cases.json")) {
            boolean ordered = canonical(row.get("left")).equals(canonical(row.get("right")));
            if (ordered != (boolean) sameByName.get(text(row.get("name")))) {
                disagreements++;
            }
        }
        check(disagreements > 0, "an order-sensitive comparison disagrees with Lean");
    }
}
