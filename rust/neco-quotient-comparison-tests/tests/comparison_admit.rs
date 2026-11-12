use std::collections::BTreeMap;

use neco_quotient_certificate::{
    admit, check, AdmissionChecks, Certificate, CheckResult, Condition, ConditionFailure,
    DigestScope as CoreDigestScope, Expected, Mismatch, Origin, Prerequisite, ProjectionDigest,
    ProjectionDigests, ProjectionResult, ResidualSet, Rule, RuleTable, SourceChecks, SourceRef,
    Status,
};
use neco_quotient_encoding::{
    canonical_bytes, decode_canonical, normalize_residuals, sha256_hex, CertificateWire,
    DigestScope as WireDigestScope, JsonValue, ProjectionDigestWire,
};

type Cert = Certificate<String, String, String, String, String, String>;
type Exp = Expected<String, String, String, String, String>;
type Table = RuleTable<String, String, String, String, String>;

const REVISION: &str = "comparison/sha256@1";
const SALTED_REVISION: &str = "comparison/salted@1";

fn evidence_digests(text: &str) -> ProjectionDigests {
    let bytes = canonical_bytes(&JsonValue::String(text.to_string()))
        .expect("the evidence text has canonical bytes");
    BTreeMap::from([(
        "evidence".to_string(),
        ProjectionDigest {
            digest: sha256_hex(&bytes).expect("the evidence bytes have a SHA-256 digest"),
            scope: CoreDigestScope::CrossLanguage("sha256".into()),
        },
    )])
}

struct ComparisonRule;

impl Rule<String, String, String, String, String> for ComparisonRule {
    fn recompute(
        &self,
        _source: &SourceRef<String, String>,
        _coordinate: &String,
        _observations: &String,
        evidence: &String,
    ) -> ProjectionDigests {
        evidence_digests(evidence)
    }
}

struct SaltedRule(&'static str);

impl Rule<String, String, String, String, String> for SaltedRule {
    fn recompute(
        &self,
        _source: &SourceRef<String, String>,
        _coordinate: &String,
        _observations: &String,
        evidence: &String,
    ) -> ProjectionDigests {
        evidence_digests(&format!("{}|{}", self.0, evidence))
    }
}

fn comparison_table() -> Table {
    let rule: Box<dyn Rule<String, String, String, String, String> + Send + Sync> =
        Box::new(ComparisonRule);
    RuleTable::new(vec![(REVISION.to_string(), rule)]).expect("the table has one revision")
}

fn read_bytes(name: &str) -> &'static [u8] {
    match name {
        "cases.json" => include_bytes!("../../../comparison/certificate-admit/cases.json"),
        "lean-outcomes.json" => {
            include_bytes!("../../../comparison/certificate-admit/lean-outcomes.json")
        }
        "residual-set-api-cases-v1.json" => {
            include_bytes!("../../../comparison/certificate-admit/residual-set-api-cases-v1.json")
        }
        "residual-set-api-outcomes-v1.json" => {
            include_bytes!(
                "../../../comparison/certificate-admit/residual-set-api-outcomes-v1.json"
            )
        }
        _ => panic!("unknown corpus file: {name}"),
    }
}

fn corpus() -> Vec<JsonValue> {
    let value = decode_canonical(read_bytes("cases.json"))
        .unwrap_or_else(|failure| panic!("cases.json: {failure}"));
    value
        .as_array()
        .expect("the corpus root is an array")
        .to_vec()
}

fn residual_set_api_corpus() -> Vec<JsonValue> {
    let value = decode_canonical(read_bytes("residual-set-api-cases-v1.json"))
        .unwrap_or_else(|failure| panic!("residual-set-api-cases-v1.json: {failure}"));
    value
        .as_array()
        .expect("the versioned API corpus root is an array")
        .to_vec()
}

fn field<'a>(object: &'a JsonValue, key: &str) -> &'a JsonValue {
    object
        .get(key)
        .unwrap_or_else(|| panic!("missing field {key}"))
}

fn text(value: &JsonValue) -> String {
    value.as_str().expect("the value is a string").to_string()
}

fn string(value: &str) -> JsonValue {
    JsonValue::String(value.to_string())
}

fn object(fields: Vec<(&str, JsonValue)>) -> JsonValue {
    JsonValue::Object(
        fields
            .into_iter()
            .map(|(key, value)| (key.to_string(), value))
            .collect(),
    )
}

fn source_of(object: &JsonValue) -> SourceRef<String, String> {
    SourceRef {
        identity: text(field(object, "identity")),
        revision: text(field(object, "revision")),
    }
}

fn core_digest(digest: &ProjectionDigestWire) -> ProjectionDigest {
    let scope = match &digest.scope {
        WireDigestScope::WithinRuntime(name) => CoreDigestScope::WithinRuntime(name.clone()),
        WireDigestScope::CrossLanguage(name) => CoreDigestScope::CrossLanguage(name.clone()),
    };
    ProjectionDigest {
        digest: digest.digest.clone(),
        scope,
    }
}

fn core_digests(digests: &BTreeMap<String, ProjectionDigestWire>) -> ProjectionDigests {
    digests
        .iter()
        .map(|(name, digest)| (name.clone(), core_digest(digest)))
        .collect()
}

fn certificate_from_value(value: &JsonValue) -> Cert {
    let wire = CertificateWire::from_value(value)
        .unwrap_or_else(|failure| panic!("certificate: {failure}"));
    Certificate {
        rule_revision: wire.rule_revision.clone(),
        source: SourceRef {
            identity: wire.source.identity.clone(),
            revision: wire.source.revision.clone(),
        },
        coordinate: text(&wire.coordinate),
        digests: core_digests(&wire.digests),
        residuals: ResidualSet::new(wire.residuals.iter().map(text)),
        observations: text(&wire.observations),
        evidence: text(&wire.evidence),
    }
}

fn certificate_of(row: &JsonValue) -> Cert {
    certificate_from_value(field(row, "certificate"))
}

fn residual_set_api_certificate_of(row: &JsonValue) -> Cert {
    let object = field(row, "certificate");
    let digests = field(object, "digests")
        .as_object()
        .expect("digests is an object")
        .iter()
        .map(|(name, digest)| {
            let scope = field(digest, "scope");
            let scope = if let Some(name) = scope.get("cross_language") {
                CoreDigestScope::CrossLanguage(text(name))
            } else if let Some(name) = scope.get("within_runtime") {
                CoreDigestScope::WithinRuntime(text(name))
            } else {
                panic!("unknown digest scope");
            };
            (
                name.clone(),
                ProjectionDigest {
                    digest: text(field(digest, "digest")),
                    scope,
                },
            )
        })
        .collect();
    let residuals = field(object, "residuals")
        .as_array()
        .expect("residuals is an array")
        .iter()
        .map(text)
        .collect::<Vec<_>>();
    Certificate {
        rule_revision: text(field(object, "rule_revision")),
        source: source_of(field(object, "source")),
        coordinate: text(field(object, "coordinate")),
        digests,
        residuals: ResidualSet::new(residuals),
        observations: text(field(object, "observations")),
        evidence: text(field(object, "evidence")),
    }
}

fn expected_of(row: &JsonValue) -> Exp {
    let object = field(row, "expected");
    let residuals: Vec<String> = field(object, "residuals")
        .as_array()
        .expect("residuals is an array")
        .iter()
        .map(text)
        .collect();
    Expected {
        rule_revision: text(field(object, "rule_revision")),
        source: source_of(field(object, "source")),
        coordinate: text(field(object, "coordinate")),
        observations: text(field(object, "observations")),
        residuals: ResidualSet::new(residuals),
    }
}

fn scope_json(scope: &CoreDigestScope) -> JsonValue {
    match scope {
        CoreDigestScope::WithinRuntime(name) => object(vec![("within_runtime", string(name))]),
        CoreDigestScope::CrossLanguage(name) => object(vec![("cross_language", string(name))]),
    }
}

fn digest_json(digest: &ProjectionDigest) -> JsonValue {
    object(vec![
        ("digest", string(&digest.digest)),
        ("scope", scope_json(&digest.scope)),
    ])
}

fn projection_json(result: &ProjectionResult) -> JsonValue {
    match result {
        ProjectionResult::Matched(value) => object(vec![
            ("result", string("matched")),
            ("value", digest_json(value)),
        ]),
        ProjectionResult::CertificateOnly(actual) => object(vec![
            ("result", string("certificate_only")),
            ("actual", digest_json(actual)),
        ]),
        ProjectionResult::RecomputedOnly(expected) => object(vec![
            ("result", string("recomputed_only")),
            ("expected", digest_json(expected)),
        ]),
        ProjectionResult::Different { expected, actual } => object(vec![
            ("result", string("different")),
            ("expected", digest_json(expected)),
            ("actual", digest_json(actual)),
        ]),
    }
}

fn origin_json(origin: &Origin) -> JsonValue {
    object(vec![
        ("rule_revision", string(&origin.rule_revision)),
        ("source_identity", string(&origin.source_identity)),
        ("source_revision", string(&origin.source_revision)),
    ])
}

fn failure_json<St, P>(failure: &ConditionFailure<St, P>) -> JsonValue {
    object(vec![
        ("operation", string(failure.operation)),
        ("origin", origin_json(&failure.origin)),
    ])
}

fn matched_json() -> JsonValue {
    object(vec![("status", string("matched"))])
}

fn mismatched_json<St, P>(failure: &ConditionFailure<St, P>) -> JsonValue {
    object(vec![
        ("status", string("mismatched")),
        ("failure", failure_json(failure)),
    ])
}

fn unchecked_json<St, P>(prerequisite: &str, failure: &ConditionFailure<St, P>) -> JsonValue {
    object(vec![
        ("status", string("unchecked")),
        ("prerequisite", string(prerequisite)),
        ("failure", failure_json(failure)),
    ])
}

fn check_json<St, P>(result: &CheckResult<ConditionFailure<St, P>>) -> JsonValue {
    match result {
        CheckResult::Matched => matched_json(),
        CheckResult::Mismatched(failure) => mismatched_json(failure),
    }
}

fn source_child_json<St, P>(
    checks: &AdmissionChecks<P>,
    select: fn(&SourceChecks<P>) -> &CheckResult<ConditionFailure<St, P>>,
) -> JsonValue {
    match checks.source() {
        Prerequisite::Failed(failure) => unchecked_json("source", failure),
        Prerequisite::Established(children) => check_json(select(children)),
    }
}

fn digest_condition_json(checks: &AdmissionChecks<String>) -> JsonValue {
    match checks.decode() {
        Prerequisite::Failed(failure) => unchecked_json("decode", failure),
        Prerequisite::Established(results) => {
            let status = if results.values().all(ProjectionResult::is_matched) {
                "matched"
            } else {
                "mismatched"
            };
            let projections = results
                .iter()
                .map(|(name, result)| (name.clone(), projection_json(result)))
                .collect();
            object(vec![
                ("status", string(status)),
                ("projections", JsonValue::Object(projections)),
            ])
        }
    }
}

fn conditions_json(checks: &AdmissionChecks<String>) -> JsonValue {
    let decode = match checks.decode() {
        Prerequisite::Failed(failure) => mismatched_json(failure),
        Prerequisite::Established(_) => matched_json(),
    };
    let source = match checks.source() {
        Prerequisite::Failed(failure) => mismatched_json(failure),
        Prerequisite::Established(_) => matched_json(),
    };
    object(vec![
        ("decode", decode),
        ("source", source),
        ("digest", digest_condition_json(checks)),
        (
            "coordinate",
            source_child_json(checks, SourceChecks::coordinate),
        ),
        (
            "observations",
            source_child_json(checks, SourceChecks::observations),
        ),
        (
            "residual",
            source_child_json(checks, SourceChecks::residual),
        ),
    ])
}

fn outcome_json(
    name: &str,
    accepted: bool,
    checks: &AdmissionChecks<String>,
    certificate: &Cert,
) -> JsonValue {
    let mut residuals: Vec<String> = certificate.residuals.iter().cloned().collect();
    residuals.sort();
    object(vec![
        ("accepted", JsonValue::Bool(accepted)),
        ("conditions", conditions_json(checks)),
        ("name", string(name)),
        (
            "residuals",
            JsonValue::Array(residuals.into_iter().map(JsonValue::String).collect()),
        ),
    ])
}

struct Run {
    name: String,
    provenance: String,
    certificate: Cert,
    checks: AdmissionChecks<String>,
    outcome: JsonValue,
    mismatch: Option<Mismatch<String>>,
    admitted: Option<(Cert, ProjectionDigests)>,
}

fn run_case(table: &Table, row: &JsonValue) -> Run {
    run_case_with_certificate(table, row, certificate_of(row))
}

fn run_residual_set_api_case(table: &Table, row: &JsonValue) -> Run {
    run_case_with_certificate(table, row, residual_set_api_certificate_of(row))
}

#[allow(clippy::result_large_err)]
fn run_case_with_certificate(table: &Table, row: &JsonValue, certificate: Cert) -> Run {
    let name = text(field(row, "name"));
    let provenance = text(field(row, "provenance"));
    let expected = expected_of(row);
    let checks = check(table, &certificate, &expected, provenance.clone());
    let (accepted, mismatch, admitted) =
        match admit(table, certificate.clone(), expected, provenance.clone()) {
            Ok(checked) => {
                assert!(
                    checks.all_matched(),
                    "case {name}: admitted although a condition did not match"
                );
                let admitted = (checked.certificate().clone(), checked.recomputed().clone());
                (true, None, Some(admitted))
            }
            Err(mismatch) => {
                assert!(
                    !checks.all_matched(),
                    "case {name}: rejected although every condition matched"
                );
                assert_eq!(mismatch.checks(), &checks, "case {name}");
                (false, Some(mismatch), None)
            }
        };
    let outcome = outcome_json(&name, accepted, &checks, &certificate);
    Run {
        name,
        provenance,
        certificate,
        checks,
        outcome,
        mismatch,
        admitted,
    }
}

fn runs() -> Vec<Run> {
    let table = comparison_table();
    corpus().iter().map(|row| run_case(&table, row)).collect()
}

fn run_named<'a>(runs: &'a [Run], name: &str) -> &'a Run {
    runs.iter()
        .find(|run| run.name == name)
        .unwrap_or_else(|| panic!("missing case {name}"))
}

fn status_word(status: Status<'_, String>) -> &'static str {
    match status {
        Status::Matched => "matched",
        Status::Mismatched => "mismatched",
        Status::UncheckedByDecode(_) | Status::UncheckedBySource(_) => "unchecked",
    }
}

fn statuses(checks: &AdmissionChecks<String>) -> [&'static str; 6] {
    Condition::ALL.map(|condition| status_word(checks.status_at(condition)))
}

fn projection_kind(result: &ProjectionResult) -> &'static str {
    match result {
        ProjectionResult::Matched(_) => "matched",
        ProjectionResult::CertificateOnly(_) => "certificate_only",
        ProjectionResult::RecomputedOnly(_) => "recomputed_only",
        ProjectionResult::Different { .. } => "different",
    }
}

fn projection_kinds(checks: &AdmissionChecks<String>) -> Vec<(&str, &'static str)> {
    match checks.decode() {
        Prerequisite::Failed(_) => Vec::new(),
        Prerequisite::Established(results) => results
            .iter()
            .map(|(name, result)| (name.as_str(), projection_kind(result)))
            .collect(),
    }
}

fn failure_records(checks: &AdmissionChecks<String>) -> Vec<(&Origin, &String)> {
    let mut records = Vec::new();
    if let Prerequisite::Failed(failure) = checks.decode() {
        records.push((&failure.origin, &failure.provenance));
    }
    if let Prerequisite::Failed(failure) = checks.source() {
        records.push((&failure.origin, &failure.provenance));
    }
    if let Prerequisite::Established(children) = checks.source() {
        for failure in [
            children
                .coordinate()
                .failure()
                .map(|f| (&f.origin, &f.provenance)),
            children
                .observations()
                .failure()
                .map(|f| (&f.origin, &f.provenance)),
            children
                .residual()
                .failure()
                .map(|f| (&f.origin, &f.provenance)),
        ]
        .into_iter()
        .flatten()
        {
            records.push(failure);
        }
    }
    records
}

#[test]
fn admission_projection_matches_lean_outcomes_byte_for_byte() {
    let outcomes: Vec<JsonValue> = runs().into_iter().map(|run| run.outcome).collect();
    let rust_bytes =
        canonical_bytes(&JsonValue::Array(outcomes)).expect("the outcomes have canonical bytes");
    assert_eq!(rust_bytes, read_bytes("lean-outcomes.json"));
}

#[test]
fn versioned_residual_set_api_projection_matches_lean_outcomes_byte_for_byte() {
    let table = comparison_table();
    let runs: Vec<Run> = residual_set_api_corpus()
        .iter()
        .map(|row| run_residual_set_api_case(&table, row))
        .collect();
    let outcomes: Vec<JsonValue> = runs.iter().map(|run| run.outcome.clone()).collect();
    let rust_bytes =
        canonical_bytes(&JsonValue::Array(outcomes)).expect("the outcomes are encoded");
    assert_eq!(rust_bytes, read_bytes("residual-set-api-outcomes-v1.json"));
    assert_eq!(runs.len(), 2);
    assert_eq!(runs[0].name, "residual_order_and_duplicates");
    assert!(runs[0].mismatch.is_none());
    assert_eq!(runs[1].name, "residual_membership");
    let mismatch = runs[1]
        .mismatch
        .as_ref()
        .expect("the membership case is rejected");
    assert!(matches!(
        mismatch.status_at(Condition::Residual),
        Status::Mismatched
    ));
}

#[test]
fn corpus_condition_statuses_match_the_named_cases() {
    const EXPECTED: [(&str, [&str; 6]); 21] = [
        (
            "accepted_plain",
            [
                "matched", "matched", "matched", "matched", "matched", "matched",
            ],
        ),
        (
            "accepted_unicode_control",
            [
                "matched", "matched", "matched", "matched", "matched", "matched",
            ],
        ),
        (
            "decode_version",
            [
                "mismatched",
                "matched",
                "matched",
                "matched",
                "unchecked",
                "matched",
            ],
        ),
        (
            "decode_unknown_rule",
            [
                "mismatched",
                "matched",
                "matched",
                "matched",
                "unchecked",
                "matched",
            ],
        ),
        (
            "source_identity",
            [
                "matched",
                "mismatched",
                "unchecked",
                "unchecked",
                "matched",
                "unchecked",
            ],
        ),
        (
            "coordinate",
            [
                "matched",
                "matched",
                "mismatched",
                "matched",
                "matched",
                "matched",
            ],
        ),
        (
            "observations",
            [
                "matched",
                "matched",
                "matched",
                "mismatched",
                "matched",
                "matched",
            ],
        ),
        (
            "digest",
            [
                "matched",
                "matched",
                "matched",
                "matched",
                "mismatched",
                "matched",
            ],
        ),
        (
            "source_with_dependents",
            [
                "matched",
                "mismatched",
                "unchecked",
                "unchecked",
                "mismatched",
                "unchecked",
            ],
        ),
        (
            "both_roots_fail",
            [
                "mismatched",
                "mismatched",
                "unchecked",
                "unchecked",
                "unchecked",
                "unchecked",
            ],
        ),
        (
            "unknown_rule_and_source_fail",
            [
                "mismatched",
                "mismatched",
                "unchecked",
                "unchecked",
                "unchecked",
                "unchecked",
            ],
        ),
        (
            "decode_fail_children_fail",
            [
                "mismatched",
                "matched",
                "mismatched",
                "mismatched",
                "unchecked",
                "mismatched",
            ],
        ),
        (
            "source_and_digest_fail",
            [
                "matched",
                "mismatched",
                "unchecked",
                "unchecked",
                "mismatched",
                "unchecked",
            ],
        ),
        (
            "independent_children_fail",
            [
                "matched",
                "matched",
                "mismatched",
                "mismatched",
                "matched",
                "mismatched",
            ],
        ),
        (
            "all_independent_fail",
            [
                "matched",
                "matched",
                "mismatched",
                "mismatched",
                "mismatched",
                "mismatched",
            ],
        ),
        (
            "digest_names_mixed",
            [
                "matched",
                "matched",
                "matched",
                "matched",
                "mismatched",
                "matched",
            ],
        ),
        (
            "digest_recomputed_only",
            [
                "matched",
                "matched",
                "matched",
                "matched",
                "mismatched",
                "matched",
            ],
        ),
        (
            "digest_value_and_certificate_only",
            [
                "matched",
                "matched",
                "matched",
                "matched",
                "mismatched",
                "matched",
            ],
        ),
        (
            "digest_utf8_utf16_key_order",
            [
                "matched",
                "matched",
                "matched",
                "matched",
                "mismatched",
                "matched",
            ],
        ),
        (
            "digest_key_change_isolated",
            [
                "matched",
                "matched",
                "matched",
                "matched",
                "mismatched",
                "matched",
            ],
        ),
        (
            "digest_keys_both_sides",
            [
                "matched",
                "matched",
                "matched",
                "matched",
                "mismatched",
                "matched",
            ],
        ),
    ];
    let runs = runs();
    assert_eq!(runs.len(), EXPECTED.len());
    for (name, expected) in EXPECTED {
        assert_eq!(
            statuses(&run_named(&runs, name).checks),
            expected,
            "case {name}"
        );
    }
}

#[test]
fn projection_results_classify_one_sided_and_differing_names() {
    let runs = runs();
    let cases: Vec<(&str, Vec<(&str, &str)>)> = vec![
        ("accepted_plain", vec![("evidence", "matched")]),
        ("digest", vec![("evidence", "different")]),
        (
            "digest_names_mixed",
            vec![
                ("alpha", "certificate_only"),
                ("evidence", "different"),
                ("zeta", "certificate_only"),
            ],
        ),
        (
            "digest_recomputed_only",
            vec![("evidence", "recomputed_only")],
        ),
        (
            "digest_value_and_certificate_only",
            vec![
                ("evidence", "different"),
                ("extra-one", "certificate_only"),
                ("extra-two", "certificate_only"),
            ],
        ),
        (
            "digest_utf8_utf16_key_order",
            vec![
                ("evidence", "matched"),
                ("\u{ff5e}", "certificate_only"),
                ("\u{1f600}", "certificate_only"),
            ],
        ),
        (
            "digest_key_change_isolated",
            vec![("evidence", "matched"), ("other", "certificate_only")],
        ),
        (
            "digest_keys_both_sides",
            vec![
                ("evidence", "recomputed_only"),
                ("extra", "certificate_only"),
            ],
        ),
    ];
    for (name, expected) in cases {
        assert_eq!(
            projection_kinds(&run_named(&runs, name).checks),
            expected,
            "case {name}"
        );
    }
}

#[test]
fn unchecked_status_holds_exactly_when_the_prerequisite_fails() {
    for run in runs() {
        for condition in Condition::ALL {
            let status = run.checks.status_at(condition);
            let unchecked = matches!(
                status,
                Status::UncheckedByDecode(_) | Status::UncheckedBySource(_)
            );
            if matches!(status, Status::UncheckedByDecode(_)) {
                assert_eq!(condition, Condition::Digest, "case {}", run.name);
            }
            match condition.prerequisite() {
                None => assert!(!unchecked, "case {} {:?}", run.name, condition),
                Some(prerequisite) => assert_eq!(
                    unchecked,
                    matches!(run.checks.status_at(prerequisite), Status::Mismatched),
                    "case {} {:?}",
                    run.name,
                    condition
                ),
            }
        }
    }
}

#[test]
fn failures_keep_the_input_provenance_and_the_certificate_origin() {
    let mut failing = 0;
    for run in runs() {
        let Some(mismatch) = &run.mismatch else {
            continue;
        };
        failing += 1;
        assert_eq!(mismatch.provenance(), &run.provenance);
        assert_eq!(
            mismatch.origin().rule_revision,
            run.certificate.rule_revision
        );
        assert_eq!(
            mismatch.origin().source_identity,
            run.certificate.source.identity
        );
        assert_eq!(run.provenance, format!("caller/{}", run.name));
        let records = failure_records(&run.checks);
        if records.is_empty() {
            assert!(
                matches!(run.checks.status_at(Condition::Digest), Status::Mismatched),
                "case {}: a failure without a record must be a digest mismatch",
                run.name
            );
        }
        for (origin, provenance) in records {
            assert_eq!(provenance, &run.provenance, "case {}", run.name);
            assert_eq!(origin.rule_revision, run.certificate.rule_revision);
            assert_eq!(origin.source_identity, run.certificate.source.identity);
            assert_eq!(origin.source_revision, run.certificate.source.revision);
        }
    }
    assert_eq!(failing, 19);
}

#[test]
fn accepted_certificates_return_the_certificate_and_the_recomputed_digest() {
    let mut accepted = 0;
    for run in runs() {
        if let Some((admitted, recomputed)) = &run.admitted {
            accepted += 1;
            assert_eq!(admitted, &run.certificate);
            assert_eq!(recomputed, &run.certificate.digests);
        }
    }
    assert_eq!(accepted, 2);
}

#[test]
fn corpus_residuals_are_compared_as_sets_in_normal_form() {
    for row in corpus() {
        for object in [field(&row, "certificate"), field(&row, "expected")] {
            let residuals = field(object, "residuals")
                .as_array()
                .expect("residuals is an array")
                .to_vec();
            assert_eq!(
                normalize_residuals(residuals.clone()).expect("wire residuals normalize"),
                residuals
            );
        }
    }
}

#[test]
fn reversed_digest_keys_in_the_input_give_the_same_certificate_and_bytes() {
    fn with_reversed_digests(value: &JsonValue) -> JsonValue {
        let JsonValue::Object(fields) = value else {
            panic!("the certificate is an object");
        };
        JsonValue::Object(
            fields
                .iter()
                .map(|(key, child)| {
                    if key == "digests" {
                        let JsonValue::Object(entries) = child else {
                            panic!("digests is an object");
                        };
                        (
                            key.clone(),
                            JsonValue::Object(entries.iter().rev().cloned().collect()),
                        )
                    } else {
                        (key.clone(), child.clone())
                    }
                })
                .collect(),
        )
    }

    let table = comparison_table();
    for row in corpus() {
        let original = field(&row, "certificate");
        let reversed = with_reversed_digests(original);
        assert_eq!(
            certificate_from_value(original),
            certificate_from_value(&reversed)
        );
        assert_eq!(
            CertificateWire::from_value(original)
                .expect("the corpus certificate decodes")
                .canonical_bytes()
                .expect("the corpus certificate has canonical bytes"),
            CertificateWire::from_value(&reversed)
                .expect("the reversed certificate decodes")
                .canonical_bytes()
                .expect("the reversed certificate has canonical bytes"),
        );
        let name = text(field(&row, "name"));
        let reversed_run =
            run_case_with_certificate(&table, &row, certificate_from_value(&reversed));
        let original_run = run_case(&table, &row);
        assert_eq!(reversed_run.checks, original_run.checks, "case {name}");
    }
}

fn table_in_order(reversed: bool) -> Table {
    let comparison: Box<dyn Rule<String, String, String, String, String> + Send + Sync> =
        Box::new(ComparisonRule);
    let salted: Box<dyn Rule<String, String, String, String, String> + Send + Sync> =
        Box::new(SaltedRule("salt-v2"));
    let mut entries = vec![
        (REVISION.to_string(), comparison),
        (SALTED_REVISION.to_string(), salted),
    ];
    if reversed {
        entries.reverse();
    }
    RuleTable::new(entries).expect("the revisions are distinct")
}

type Outcome = Result<(Cert, ProjectionDigests), Mismatch<String>>;

#[allow(clippy::result_large_err)]
fn outcome(table: &Table, certificate: Cert, expected: Exp, provenance: &str) -> Outcome {
    admit(table, certificate, expected, provenance.to_string())
        .map(|checked| (checked.certificate().clone(), checked.recomputed().clone()))
}

#[test]
fn table_order_does_not_change_rule_selection_or_admission() {
    let source = SourceRef {
        identity: "source-alpha".to_string(),
        revision: "rev-1".to_string(),
    };
    let coordinate = "coord-a".to_string();
    let observations = "observations-a".to_string();
    let residuals = vec!["residual-a".to_string(), "residual-b".to_string()];
    let evidence = "evidence-plain".to_string();
    let comparison_digests =
        ComparisonRule.recompute(&source, &coordinate, &observations, &evidence);
    let salted_digests =
        SaltedRule("salt-v2").recompute(&source, &coordinate, &observations, &evidence);
    assert_ne!(comparison_digests, salted_digests);

    let make_cert = |revision: &str, digests: &ProjectionDigests| -> Cert {
        Certificate {
            rule_revision: revision.to_string(),
            source: source.clone(),
            coordinate: coordinate.clone(),
            digests: digests.clone(),
            residuals: ResidualSet::new(residuals.clone()),
            observations: observations.clone(),
            evidence: evidence.clone(),
        }
    };
    let make_expected = |revision: &str| -> Exp {
        Expected {
            rule_revision: revision.to_string(),
            source: source.clone(),
            coordinate: coordinate.clone(),
            observations: observations.clone(),
            residuals: ResidualSet::new(residuals.clone()),
        }
    };

    let cases: Vec<(&str, bool, Cert, Exp)> = vec![
        (
            "comparison digest under its own version",
            true,
            make_cert(REVISION, &comparison_digests),
            make_expected(REVISION),
        ),
        (
            "salted digest under its own version",
            true,
            make_cert(SALTED_REVISION, &salted_digests),
            make_expected(SALTED_REVISION),
        ),
        (
            "comparison digest under the salted version",
            false,
            make_cert(SALTED_REVISION, &comparison_digests),
            make_expected(SALTED_REVISION),
        ),
        (
            "salted digest under the comparison version",
            false,
            make_cert(REVISION, &salted_digests),
            make_expected(REVISION),
        ),
    ];

    let forward = table_in_order(false);
    let reversed = table_in_order(true);
    for (name, should_accept, certificate, expected) in cases {
        let from_forward = outcome(&forward, certificate.clone(), expected.clone(), name);
        let from_reversed = outcome(&reversed, certificate, expected, name);
        assert_eq!(from_forward, from_reversed, "case {name}");
        assert_eq!(from_forward.is_ok(), should_accept, "case {name}");
        match &from_forward {
            Ok((admitted, recomputed)) => {
                assert_eq!(recomputed, &admitted.digests, "case {name}");
            }
            Err(mismatch) => {
                assert!(
                    matches!(mismatch.status_at(Condition::Digest), Status::Mismatched),
                    "case {name}"
                );
                assert!(
                    matches!(mismatch.status_at(Condition::Decode), Status::Matched),
                    "case {name}"
                );
                assert_eq!(mismatch.provenance().as_str(), name);
            }
        }
    }
}
