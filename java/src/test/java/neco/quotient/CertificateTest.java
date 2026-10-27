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
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeMap;
import java.util.stream.Collectors;

public final class CertificateTest {

    static final String REVISION = "comparison/sha256@1";
    static final String OTHER_REVISION = "comparison/sha256@2";
    static final Stage[] STAGES = Stage.values();

    static final Rule<String, String, String, String, String> COMPARISON =
            (source, coordinate, observations, evidence) -> List.of(
                    new ProjectionDigest("evidence", ComparisonEvidence.digest(evidence),
                            new DigestScope.CrossLanguage("sha256")));

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
                new TestCase("corpus stage counts", CertificateTest::corpusStageCounts),
                new TestCase("corpus accepted rows return certificate and recomputed digests",
                        CertificateTest::corpusAcceptedRowsReturnCertificateAndRecomputed),
                new TestCase("corpus rejected rows keep provenance and origin",
                        CertificateTest::corpusRejectedRowsKeepProvenanceAndOrigin),
                new TestCase("json reader decodes escapes and unicode", CertificateTest::jsonReaderDecodesEscapes),
                new TestCase("canonical JSON string escapes", CertificateTest::canonicalStringEscapes),
                new TestCase("decode version is reported before table lookup",
                        CertificateTest::decodeVersionIsReportedBeforeLookup),
                new TestCase("each stage alone is reported at that stage", CertificateTest::eachStageAloneIsReported),
                new TestCase("first failure wins over every later stage", CertificateTest::firstFailureWinsOverLaterStages),
                new TestCase("evidence change alone is rejected at digest", CertificateTest::evidenceChangeAloneIsDigest),
                new TestCase("digest scope kind and payload are compared", CertificateTest::digestScopeKindAndPayloadAreCompared),
                new TestCase("digest list order and length are compared", CertificateTest::digestOrderAndLengthAreCompared),
                new TestCase("residual order and duplicates compare by membership", CertificateTest::residualMembershipIsCompared),
                new TestCase("duplicate rule revision is a typed failure at construction",
                        CertificateTest::duplicateRuleIsATypedFailureAtConstruction),
                new TestCase("table is independent from the mutable input list",
                        CertificateTest::tableIsIndependentFromInputList),
                new TestCase("table order does not change the selected rule",
                        CertificateTest::tableOrderDoesNotChangeSelectedRule),
                new TestCase("certificate lists are detached from the input lists",
                        CertificateTest::certificateListsAreDetachedFromInput),
                new TestCase("provenance is returned unchanged", CertificateTest::provenanceIsReturnedUnchanged),
                new TestCase("checked value exposes certificate, source and recomputed digests",
                        CertificateTest::checkedValueExposesAdmittedParts),
                new TestCase("record values compare by components", CertificateTest::recordValuesCompareByComponents),
                new TestCase("mismatch description names operation, stage and origin",
                        CertificateTest::mismatchDescriptionNamesOperationStageAndOrigin),
                new TestCase("public api boundary", CertificateTest::publicApiBoundary)
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

    static List<ProjectionDigest> digestsOf(String evidence) {
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
        List<ProjectionDigest> digests = digestsOf("evidence-plain");
        List<String> residuals = List.of("residual-a", "residual-b");

        Certificate<String, String, String, String, String, String> certificate() {
            return new Certificate<>(ruleRevision, new SourceRef<>(identity, revision), coordinate,
                    digests, residuals, observations, evidence);
        }
    }

    static void breakStage(Draft draft, Stage stage) {
        switch (stage) {
            case DECODE -> draft.ruleRevision = OTHER_REVISION;
            case SOURCE -> draft.identity = "source-beta";
            case COORDINATE -> draft.coordinate = "coord-b";
            case OBSERVATIONS -> draft.observations = "observations-b";
            case DIGEST -> draft.digests = List.of(
                    new ProjectionDigest("evidence", "0".repeat(64), new DigestScope.CrossLanguage("sha256")));
            case RESIDUAL -> draft.residuals = List.of("residual-c");
        }
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

    static Certificate<String, String, String, String, String, String> certificateOf(Map<String, Object> object) {
        Map<String, Object> source = map(object.get("source"));
        List<ProjectionDigest> digests = new ArrayList<>();
        for (Object item : list(object.get("digests"))) {
            Map<String, Object> digest = map(item);
            Map<String, Object> scope = map(digest.get("scope"));
            DigestScope value;
            if (scope.size() == 1 && scope.containsKey("within_runtime")) {
                value = new DigestScope.WithinRuntime(text(scope.get("within_runtime")));
            } else if (scope.size() == 1 && scope.containsKey("cross_language")) {
                value = new DigestScope.CrossLanguage(text(scope.get("cross_language")));
            } else {
                throw new AssertionError("unknown digest scope " + scope);
            }
            digests.add(new ProjectionDigest(text(digest.get("projection")), text(digest.get("digest")), value));
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

    static Result<Checked<String, String, String, String, String, String>, Mismatch<String>> runRow(
            RuleTable<String, String, String, String, String> table, Map<String, Object> row) {
        return Checked.admit(table, certificateOf(map(row.get("certificate"))),
                expectedOf(map(row.get("expected"))), text(row.get("provenance")));
    }

    static Map<String, Object> projection(String name,
            Certificate<String, String, String, String, String, String> certificate,
            Result<?, Mismatch<String>> result) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("name", name);
        var residuals = certificate.residuals().values().stream().sorted().toList();
        out.put("residuals", residuals);
        if (result instanceof Result.Accepted<?, Mismatch<String>>) {
            out.put("accepted", true);
            return out;
        }
        Mismatch<String> mismatch = rejectedOf(result);
        Map<String, Object> origin = new LinkedHashMap<>();
        origin.put("rule_revision", mismatch.origin().ruleRevision());
        origin.put("source_identity", mismatch.origin().sourceIdentity());
        origin.put("source_revision", mismatch.origin().sourceRevision());
        Map<String, Object> failure = new LinkedHashMap<>();
        failure.put("operation", mismatch.operation());
        failure.put("origin", origin);
        failure.put("stage", mismatch.stage().label());
        out.put("accepted", false);
        out.put("failure", failure);
        return out;
    }

    static void corpusOutcomesEqualLeanOutcomes() throws IOException {
        var table = comparisonTable();
        var cases = rows("cases.json");
        var lean = rows("lean-outcomes.json");
        same(9, cases.size(), "case count");
        same(cases.size(), lean.size(), "lean row count");
        for (int i = 0; i < cases.size(); i++) {
            Map<String, Object> row = cases.get(i);
            String name = text(row.get("name"));
            same(text(lean.get(i).get("name")), name, "row order at " + i);
            var certificate = certificateOf(map(row.get("certificate")));
            var result = runRow(table, row);
            same(lean.get(i), projection(name, certificate, result), "outcome of " + name);
        }
    }

    static void residualSetApiCasesEqualLeanOutcomes() throws IOException {
        var table = comparisonTable();
        var cases = rows("residual-set-api-cases-v1.json");
        var lean = rows("residual-set-api-outcomes-v1.json");
        same(2, cases.size(), "versioned API case count");
        same(cases.size(), lean.size(), "versioned API Lean row count");
        for (int i = 0; i < cases.size(); i++) {
            Map<String, Object> row = cases.get(i);
            String name = text(row.get("name"));
            same(text(lean.get(i).get("name")), name, "versioned API row order at " + i);
            var certificate = certificateOf(map(row.get("certificate")));
            var result = runRow(table, row);
            same(lean.get(i), projection(name, certificate, result), "versioned API outcome of " + name);
        }
        check(Boolean.TRUE.equals(lean.get(0).get("accepted")), "order and duplicates are accepted");
        same("residual", map(lean.get(1).get("failure")).get("stage"), "different membership is rejected");
    }

    static void corpusStageCounts() throws IOException {
        var table = comparisonTable();
        Map<String, Integer> counts = new TreeMap<>();
        for (Map<String, Object> row : rows("cases.json")) {
            var result = runRow(table, row);
            String key = result instanceof Result.Accepted<?, ?>
                    ? "accepted"
                    : rejectedOf(result).stage().label();
            counts.merge(key, 1, Integer::sum);
        }
        same(Map.of("accepted", 2, "decode", 2, "source", 2, "coordinate", 1,
                "observations", 1, "digest", 1), counts, "stage counts");
    }

    static void corpusAcceptedRowsReturnCertificateAndRecomputed() throws IOException {
        var table = comparisonTable();
        for (Map<String, Object> row : rows("cases.json")) {
            var result = runRow(table, row);
            if (!(result instanceof Result.Accepted<?, ?>)) {
                continue;
            }
            var checked = acceptedOf(result);
            var expectedCertificate = certificateOf(map(row.get("certificate")));
            same(expectedCertificate, checked.certificate(), "certificate of " + row.get("name"));
            var source = expectedCertificate.source();
            var recomputed = COMPARISON.recompute(source, expectedCertificate.coordinate(),
                    expectedCertificate.observations(), expectedCertificate.evidence());
            same(recomputed, checked.recomputed(), "recomputed digests of " + row.get("name"));
            same(expectedCertificate.digests(), checked.recomputed(), "digests equal recomputation of " + row.get("name"));
        }
    }

    static void corpusRejectedRowsKeepProvenanceAndOrigin() throws IOException {
        var table = comparisonTable();
        int rejected = 0;
        for (Map<String, Object> row : rows("cases.json")) {
            var result = runRow(table, row);
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
            check(mismatch.contributing().isEmpty(), "single admit has no contributing mismatch");
            check(mismatch.expected() != null && mismatch.actual() != null, "diagnostic text is present");
        }
        same(7, rejected, "rejected row count");
    }

    static void jsonReaderDecodesEscapes() {
        Object value = TestJson.parse("[\"\\u0000\\u001f/\\\"\\\\\\n\\t\\b\\f\\r\", \"日本語\", \"\\ud83d\\ude00\"]");
        var items = list(value);
        same("\u0000\u001f/\"\\\n\t\b\f\r", items.get(0), "escapes");
        same("日本語", items.get(1), "raw utf-8 text");
        same("\uD83D\uDE00", items.get(2), "surrogate pair escape");
    }

    static void canonicalStringEscapes() {
        same("\"\\\"\\\\\\b\\f\\n\\r\\t\\u0000\\u0001\\u001f/\u007f日本語\"",
                ComparisonEvidence.canonicalString("\"\\\b\f\n\r\t\u0000\u0001\u001f/\u007f日本語"),
                "canonical escapes");
    }

    static void decodeVersionIsReportedBeforeLookup() {
        var table = comparisonTable();
        var draft = new Draft();
        draft.ruleRevision = "comparison/sha256@9";
        var expected = new Expected<>(REVISION, new SourceRef<>("source-alpha", "rev-1"), "coord-a", "observations-a",
                List.of("residual-a", "residual-b"));
        var mismatch = rejectedOf(Checked.admit(table, draft.certificate(), expected, "caller"));
        same(Stage.DECODE, mismatch.stage(), "stage");
        same(REVISION, mismatch.expected(), "expected revision");
        same("comparison/sha256@9", mismatch.actual(), "actual revision");
    }

    static void eachStageAloneIsReported() {
        var table = comparisonTable();
        for (Stage stage : STAGES) {
            var draft = new Draft();
            breakStage(draft, stage);
            var mismatch = rejectedOf(Checked.admit(table, draft.certificate(), baseExpected(), "caller"));
            same(stage, mismatch.stage(), "stage alone " + stage);
        }
    }

    static void firstFailureWinsOverLaterStages() {
        var table = comparisonTable();
        for (int index = 0; index < STAGES.length; index++) {
            var draft = new Draft();
            for (int later = index; later < STAGES.length; later++) {
                breakStage(draft, STAGES[later]);
            }
            var mismatch = rejectedOf(Checked.admit(table, draft.certificate(), baseExpected(), "caller"));
            same(STAGES[index], mismatch.stage(), "first failure from " + STAGES[index]);
        }
    }

    static void evidenceChangeAloneIsDigest() {
        var table = comparisonTable();
        var draft = new Draft();
        draft.evidence = "evidence-other";
        var mismatch = rejectedOf(Checked.admit(table, draft.certificate(), baseExpected(), "caller"));
        same(Stage.DIGEST, mismatch.stage(), "stage");
        same(digestsOf("evidence-other").toString(), mismatch.expected(), "expected digests");
        same(draft.digests.toString(), mismatch.actual(), "actual digests");
    }

    static void digestScopeKindAndPayloadAreCompared() {
        var base = new Draft().certificate();
        for (DigestScope variant : List.of(
                new DigestScope.WithinRuntime("sha256"),
                new DigestScope.CrossLanguage("sha512"))) {
            Rule<String, String, String, String, String> rule = (source, coordinate, observations, evidence) ->
                    List.of(new ProjectionDigest("evidence", ComparisonEvidence.digest(evidence), variant));
            var table = built(RuleTable.of(List.of(entry(REVISION, rule))));
            var mismatch = rejectedOf(Checked.admit(table, base, baseExpected(), "caller"));
            same(Stage.DIGEST, mismatch.stage(), "scope " + variant);
            same(List.of(new ProjectionDigest("evidence", ComparisonEvidence.digest("evidence-plain"), variant)).toString(),
                    mismatch.expected(), "expected digest of " + variant);
        }
        check(!new DigestScope.WithinRuntime("sha256").equals(new DigestScope.CrossLanguage("sha256")),
                "kind alone distinguishes scopes");
        check(!base.digests().isEmpty(), "the fixture carries a digest");
    }

    static void digestOrderAndLengthAreCompared() {
        var first = new ProjectionDigest("alpha", "1".repeat(64), new DigestScope.CrossLanguage("sha256"));
        var second = new ProjectionDigest("beta", "2".repeat(64), new DigestScope.CrossLanguage("sha256"));
        Rule<String, String, String, String, String> rule = (source, coordinate, observations, evidence) ->
                List.of(first, second);
        var table = built(RuleTable.of(List.of(entry(REVISION, rule))));
        var reversed = new Draft();
        reversed.digests = List.of(second, first);
        same(Stage.DIGEST, rejectedOf(Checked.admit(table, reversed.certificate(), baseExpected(), "caller")).stage(),
                "reversed order");
        var truncated = new Draft();
        truncated.digests = List.of(first);
        same(Stage.DIGEST, rejectedOf(Checked.admit(table, truncated.certificate(), baseExpected(), "caller")).stage(),
                "truncated list");
        var ordered = new Draft();
        ordered.digests = List.of(first, second);
        acceptedOf(Checked.admit(table, ordered.certificate(), baseExpected(), "caller"));
    }

    static void residualMembershipIsCompared() {
        var table = comparisonTable();
        var draft = new Draft();
        draft.residuals = List.of("residual-b", "residual-a", "residual-a");
        acceptedOf(Checked.admit(table, draft.certificate(), baseExpected(), "caller"));
        draft.residuals = List.of("residual-a", "residual-c");
        same(Stage.RESIDUAL, rejectedOf(Checked.admit(table, draft.certificate(), baseExpected(), "caller")).stage(),
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
                List.of(new ProjectionDigest("evidence", "f".repeat(64), new DigestScope.CrossLanguage("sha256")));
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
        same(Stage.DECODE, mismatch.stage(), "inserted revision is not in the table");
        same("rule in table", mismatch.expected(), "table expectation");
    }

    static void tableOrderDoesNotChangeSelectedRule() {
        Rule<String, String, String, String, String> ruleA = (source, coordinate, observations, evidence) ->
                List.of(new ProjectionDigest("evidence", ComparisonEvidence.digest(evidence),
                        new DigestScope.CrossLanguage("sha256")));
        Rule<String, String, String, String, String> ruleB = (source, coordinate, observations, evidence) ->
                List.of(new ProjectionDigest("evidence", ComparisonEvidence.digest(evidence + "#b"),
                        new DigestScope.CrossLanguage("sha256")));
        List<String> revisions = List.of("comparison/sha256@1", "comparison/sha256@2");
        List<Rule<String, String, String, String, String>> rules = List.of(ruleA, ruleB);
        var forward = built(RuleTable.of(List.of(entry(revisions.get(0), ruleA), entry(revisions.get(1), ruleB))));
        var reversed = built(RuleTable.of(List.of(entry(revisions.get(1), ruleB), entry(revisions.get(0), ruleA))));
        List<RuleTable<String, String, String, String, String>> tables = List.of(forward, reversed);
        var source = new SourceRef<String, String>("source-alpha", "rev-1");
        List<String> residuals = List.of("residual-a", "residual-b");
        check(!rules.get(0).recompute(source, "coord-a", "observations-a", "evidence-plain")
                .equals(rules.get(1).recompute(source, "coord-a", "observations-a", "evidence-plain")),
                "the two rules produce different digests");
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
                same(Stage.DIGEST, rejectedOf(Checked.admit(table, wrong, expected, "caller")).stage(),
                        "other rule digests under " + revision);
            }
        }
    }

    static void certificateListsAreDetachedFromInput() {
        var digests = new ArrayList<ProjectionDigest>();
        digests.add(new ProjectionDigest("evidence", "0".repeat(64), new DigestScope.CrossLanguage("sha256")));
        var residuals = new ArrayList<String>();
        residuals.add("residual-a");
        var source = new SourceRef<String, String>("source-alpha", "rev-1");
        var certificate = new Certificate<String, String, String, String, String, String>(
                REVISION, source, "coord-a", digests, residuals, "observations-a", "evidence-plain");
        digests.clear();
        residuals.add("residual-b");
        same(1, certificate.digests().size(), "digest list is copied");
        same(ResidualSet.of(List.of("residual-a")), certificate.residuals(), "residual set is copied");
        var expectedResiduals = new ArrayList<String>(List.of("residual-a"));
        var expected = new Expected<>(REVISION, source, "coord-a", "observations-a", expectedResiduals);
        expectedResiduals.clear();
        same(ResidualSet.of(List.of("residual-a")), expected.residuals(), "expected residual set is copied");
    }

    static void provenanceIsReturnedUnchanged() {
        var table = comparisonTable();
        Object provenance = new Object();
        var draft = new Draft();
        draft.identity = "source-beta";
        var mismatch = rejectedOf(Checked.admit(table, draft.certificate(), baseExpected(), provenance));
        check(mismatch.provenance() == provenance, "the same provenance object is returned");
        check(mismatch.contributing().isEmpty(), "contributing is empty for a single admission");
    }

    static void checkedValueExposesAdmittedParts() {
        var table = comparisonTable();
        var draft = new Draft();
        var checked = acceptedOf(Checked.admit(table, draft.certificate(), baseExpected(), "caller"));
        same(draft.certificate(), checked.certificate(), "certificate");
        same(new SourceRef<>("source-alpha", "rev-1"), checked.source(), "source");
        same(digestsOf("evidence-plain"), checked.recomputed(), "recomputed digests");
        try {
            checked.recomputed().add(digestsOf("evidence-plain").get(0));
        } catch (UnsupportedOperationException expectedError) {
            return;
        }
        throw new AssertionError("recomputed digests are mutable");
    }

    static void recordValuesCompareByComponents() {
        var first = new SourceRef<>("a", 1);
        check(first.equals(new SourceRef<>("a", 1)) && first.hashCode() == new SourceRef<>("a", 1).hashCode(),
                "source refs compare by components");
        var digest = new ProjectionDigest("p", "d", new DigestScope.CrossLanguage("s"));
        check(digest.equals(new ProjectionDigest("p", "d", new DigestScope.CrossLanguage("s")))
                        && digest.hashCode() == new ProjectionDigest("p", "d", new DigestScope.CrossLanguage("s")).hashCode(),
                "projection digests compare by components");
        check(!digest.equals(new ProjectionDigest("p", "d", new DigestScope.WithinRuntime("s"))),
                "scope kind participates in equality");
        var certificate = new Draft().certificate();
        check(certificate.equals(new Draft().certificate()), "certificates compare by components");
        var reordered = new Draft();
        reordered.residuals = List.of("residual-b", "residual-a");
        check(certificate.equals(reordered.certificate()), "residual membership determines equality");
        check(baseExpected().equals(baseExpected()), "expected values compare by components");
    }

    static void mismatchDescriptionNamesOperationStageAndOrigin() {
        var table = comparisonTable();
        var draft = new Draft();
        draft.residuals = List.of("residual-c");
        var mismatch = rejectedOf(Checked.admit(table, draft.certificate(), baseExpected(), "caller"));
        same("admit failed at stage residual: expected [residual-a, residual-b], actual [residual-c] "
                        + "(rule comparison/sha256@1, source source-alpha@rev-1)",
                mismatch.describe(), "description");
    }

    static void publicApiBoundary() throws ClassNotFoundException {
        check(Modifier.isFinal(Checked.class.getModifiers()), "Checked is final");
        for (Constructor<?> constructor : Checked.class.getDeclaredConstructors()) {
            check(!Modifier.isPublic(constructor.getModifiers()), "Checked constructor is not public");
        }
        for (Constructor<?> constructor : RuleTable.class.getDeclaredConstructors()) {
            check(!Modifier.isPublic(constructor.getModifiers()), "RuleTable constructor is not public");
        }
        same(Set.of("admit", "certificate", "recomputed", "source"), publicMethodNames(Checked.class),
                "Checked public methods");
        same(Set.of("of"), publicMethodNames(RuleTable.class), "RuleTable public methods");
        check(Result.class.isSealed(), "Result is sealed");
        same(Set.of("Accepted", "Rejected"), Arrays.stream(Result.class.getPermittedSubclasses())
                .map(Class::getSimpleName).collect(Collectors.toSet()), "Result permits");
        same(List.of("value"), Arrays.stream(Result.Accepted.class.getRecordComponents())
                .map(component -> component.getName()).toList(), "Accepted components");
        same(List.of("error"), Arrays.stream(Result.Rejected.class.getRecordComponents())
                .map(component -> component.getName()).toList(), "Rejected components");
        same(List.of("ruleRevision"), Arrays.stream(DuplicateRule.class.getRecordComponents())
                .map(component -> component.getName()).toList(), "DuplicateRule components");
        check(DigestScope.class.isSealed(), "DigestScope is sealed");
        same(Set.of("WithinRuntime", "CrossLanguage"), Arrays.stream(DigestScope.class.getPermittedSubclasses())
                .map(Class::getSimpleName).collect(Collectors.toSet()), "DigestScope permits");
        same(List.of("DECODE", "SOURCE", "COORDINATE", "OBSERVATIONS", "DIGEST", "RESIDUAL"),
                Arrays.stream(Stage.values()).map(Enum::name).toList(), "stage order");
        same(List.of("ruleRevision", "source", "coordinate", "digests", "residuals", "observations", "evidence"),
                Arrays.stream(Certificate.class.getRecordComponents()).map(component -> component.getName()).toList(),
                "certificate components");
        same(List.of("operation", "stage", "expected", "actual", "origin", "provenance", "contributing"),
                Arrays.stream(Mismatch.class.getRecordComponents()).map(component -> component.getName()).toList(),
                "mismatch components");
        for (String removed : List.of("neco.quotient.Admission", "neco.quotient.DuplicateRuleException")) {
            try {
                Class.forName(removed);
            } catch (ClassNotFoundException expectedAbsence) {
                continue;
            }
            throw new AssertionError(removed + " is still present");
        }
    }

    static Set<String> publicMethodNames(Class<?> type) {
        return Arrays.stream(type.getDeclaredMethods())
                .filter(method -> Modifier.isPublic(method.getModifiers()))
                .map(Method::getName)
                .collect(Collectors.toSet());
    }
}
