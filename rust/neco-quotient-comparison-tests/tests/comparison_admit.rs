use std::collections::BTreeMap;

use neco_quotient_certificate::{
    admit, Certificate, DigestScope as CoreDigestScope, Expected, Mismatch, ProjectionDigest,
    ResidualSet, Rule, RuleTable, SourceRef, Stage,
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

struct ComparisonRule;

impl Rule<String, String, String, String, String> for ComparisonRule {
    fn recompute(
        &self,
        _source: &SourceRef<String, String>,
        _coordinate: &String,
        _observations: &String,
        evidence: &String,
    ) -> Vec<ProjectionDigest> {
        let bytes = canonical_bytes(&JsonValue::String(evidence.clone()))
            .expect("the evidence text has canonical bytes");
        vec![ProjectionDigest {
            projection: "evidence".into(),
            digest: sha256_hex(&bytes),
            scope: CoreDigestScope::CrossLanguage("sha256".into()),
        }]
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
    ) -> Vec<ProjectionDigest> {
        let salted = format!("{}|{}", self.0, evidence);
        let bytes = canonical_bytes(&JsonValue::String(salted))
            .expect("the salted text has canonical bytes");
        vec![ProjectionDigest {
            projection: "evidence".into(),
            digest: sha256_hex(&bytes),
            scope: CoreDigestScope::CrossLanguage("sha256".into()),
        }]
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
        projection: digest.projection.clone(),
        digest: digest.digest.clone(),
        scope,
    }
}

fn certificate_of(row: &JsonValue) -> Cert {
    let original = field(row, "certificate");
    let wire = CertificateWire::from_value(original)
        .unwrap_or_else(|failure| panic!("certificate: {failure}"));
    Certificate {
        rule_revision: wire.rule_revision.clone(),
        source: SourceRef {
            identity: wire.source.identity.clone(),
            revision: wire.source.revision.clone(),
        },
        coordinate: text(&wire.coordinate),
        digests: wire.digests.iter().map(core_digest).collect(),
        residuals: ResidualSet::new(wire.residuals.iter().map(text)),
        observations: text(&wire.observations),
        evidence: text(&wire.evidence),
    }
}

fn residual_set_api_certificate_of(row: &JsonValue) -> Cert {
    let object = field(row, "certificate");
    let digests = field(object, "digests")
        .as_array()
        .expect("digests is an array")
        .iter()
        .map(|digest| {
            let scope = field(digest, "scope");
            let scope = if let Some(name) = scope.get("cross_language") {
                CoreDigestScope::CrossLanguage(text(name))
            } else if let Some(name) = scope.get("within_runtime") {
                CoreDigestScope::WithinRuntime(text(name))
            } else {
                panic!("unknown digest scope");
            };
            ProjectionDigest {
                projection: text(field(digest, "projection")),
                digest: text(field(digest, "digest")),
                scope,
            }
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

fn failure_value(mismatch: &Mismatch<String>) -> JsonValue {
    JsonValue::Object(vec![
        (
            "operation".into(),
            JsonValue::String(mismatch.operation.to_string()),
        ),
        (
            "stage".into(),
            JsonValue::String(mismatch.stage.to_string()),
        ),
        (
            "origin".into(),
            JsonValue::Object(vec![
                (
                    "rule_revision".into(),
                    JsonValue::String(mismatch.origin.rule_revision.clone()),
                ),
                (
                    "source_identity".into(),
                    JsonValue::String(mismatch.origin.source_identity.clone()),
                ),
                (
                    "source_revision".into(),
                    JsonValue::String(mismatch.origin.source_revision.clone()),
                ),
            ]),
        ),
    ])
}

struct Run {
    name: String,
    provenance: String,
    certificate: Cert,
    outcome: JsonValue,
    failure: Option<Mismatch<String>>,
    recomputed: Option<Vec<ProjectionDigest>>,
    admitted: Option<Cert>,
}

fn run_case(table: &Table, row: &JsonValue) -> Run {
    run_case_with_certificate(table, row, certificate_of(row))
}

fn run_residual_set_api_case(table: &Table, row: &JsonValue) -> Run {
    run_case_with_certificate(table, row, residual_set_api_certificate_of(row))
}

fn run_case_with_certificate(table: &Table, row: &JsonValue, certificate: Cert) -> Run {
    let name = text(field(row, "name"));
    let provenance = text(field(row, "provenance"));
    let expected = expected_of(row);
    let result = admit(table, certificate.clone(), &expected, provenance.clone());
    let (accepted, failure, recomputed, admitted) = match result {
        Ok(checked) => (
            true,
            None,
            Some(checked.recomputed().to_vec()),
            Some(checked.certificate().clone()),
        ),
        Err(mismatch) => (false, Some(mismatch), None, None),
    };
    let mut fields = vec![
        ("name".to_string(), JsonValue::String(name.clone())),
        ("accepted".to_string(), JsonValue::Bool(accepted)),
        (
            "residuals".to_string(),
            JsonValue::Array({
                let mut values: Vec<JsonValue> = certificate
                    .residuals
                    .iter()
                    .cloned()
                    .map(JsonValue::String)
                    .collect();
                values.sort_by(|left, right| left.as_str().cmp(&right.as_str()));
                values
            }),
        ),
    ];
    if let Some(mismatch) = &failure {
        fields.push(("failure".to_string(), failure_value(mismatch)));
    }
    Run {
        name,
        provenance,
        certificate,
        outcome: JsonValue::Object(fields),
        failure,
        recomputed,
        admitted,
    }
}

fn runs() -> Vec<Run> {
    let table = comparison_table();
    corpus().iter().map(|row| run_case(&table, row)).collect()
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
    assert!(runs[0].failure.is_none());
    assert_eq!(runs[1].name, "residual_membership");
    assert_eq!(
        runs[1].failure.as_ref().map(|failure| failure.stage),
        Some(Stage::Residual)
    );
}

#[test]
fn failures_keep_the_input_provenance_and_the_certificate_origin() {
    let mut failing = 0;
    for run in runs() {
        if let Some(mismatch) = &run.failure {
            failing += 1;
            assert_eq!(mismatch.provenance, run.provenance);
            assert_eq!(run.provenance, format!("caller/{}", run.name));
            assert_eq!(mismatch.origin.rule_revision, run.certificate.rule_revision);
            assert_eq!(
                mismatch.origin.source_identity,
                run.certificate.source.identity
            );
            assert_eq!(
                mismatch.origin.source_revision,
                run.certificate.source.revision
            );
            assert!(mismatch.contributing.is_empty());
        }
    }
    assert_eq!(failing, 7);
}

#[test]
fn accepted_certificates_return_the_certificate_and_the_recomputed_digest() {
    let mut accepted = 0;
    for run in runs() {
        if let (Some(admitted), Some(recomputed)) = (&run.admitted, &run.recomputed) {
            accepted += 1;
            assert_eq!(admitted, &run.certificate);
            assert_eq!(recomputed, &run.certificate.digests);
        }
    }
    assert_eq!(accepted, 2);
}

#[test]
fn corpus_covers_each_stage_and_both_decode_variants() {
    let mut counts: BTreeMap<String, usize> = BTreeMap::new();
    let mut decode_expected: Vec<String> = Vec::new();
    for run in runs() {
        let key = match &run.failure {
            None => "accepted".to_string(),
            Some(mismatch) => {
                if mismatch.stage.to_string() == "decode" {
                    decode_expected.push(mismatch.expected.clone());
                }
                mismatch.stage.to_string()
            }
        };
        *counts.entry(key).or_insert(0) += 1;
    }
    let expected_counts: BTreeMap<String, usize> = [
        ("accepted", 2),
        ("decode", 2),
        ("source", 2),
        ("coordinate", 1),
        ("observations", 1),
        ("digest", 1),
    ]
    .into_iter()
    .map(|(stage, count)| (stage.to_string(), count))
    .collect();
    assert_eq!(counts, expected_counts);
    decode_expected.sort();
    assert_eq!(
        decode_expected,
        vec![
            "comparison/sha256@2".to_string(),
            "rule in table".to_string()
        ]
    );
}

#[test]
fn corpus_residuals_are_compared_as_sets_and_digests_remain_in_normal_form() {
    for row in corpus() {
        let certificate = certificate_of(&row);
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
        assert_eq!(certificate.digests.len(), 1);
        assert_eq!(certificate.digests[0].projection, "evidence");
    }
}

#[test]
fn corpus_digests_equal_independent_recomputation_except_intended_corruptions() {
    for row in corpus() {
        let certificate = certificate_of(&row);
        let bytes = canonical_bytes(&JsonValue::String(certificate.evidence.clone()))
            .expect("the evidence text has canonical bytes");
        let independent = sha256_hex(&bytes);
        let recorded = &certificate.digests[0].digest;
        let name = text(field(&row, "name"));
        let intended_corruption = matches!(name.as_str(), "digest" | "source_with_later_stages");
        assert_eq!(
            recorded == &independent,
            !intended_corruption,
            "case {name}"
        );
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

type Outcome = Result<(Cert, Vec<ProjectionDigest>), Mismatch<String>>;

#[allow(clippy::result_large_err)]
fn outcome(table: &Table, certificate: Cert, expected: &Exp, provenance: &str) -> Outcome {
    admit(table, certificate, expected, provenance.to_string())
        .map(|checked| (checked.certificate().clone(), checked.recomputed().to_vec()))
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

    let make_cert = |revision: &str, digests: &[ProjectionDigest]| -> Cert {
        Certificate {
            rule_revision: revision.to_string(),
            source: source.clone(),
            coordinate: coordinate.clone(),
            digests: digests.to_vec(),
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
        let from_forward = outcome(&forward, certificate.clone(), &expected, name);
        let from_reversed = outcome(&reversed, certificate, &expected, name);
        assert_eq!(from_forward, from_reversed, "case {name}");
        assert_eq!(from_forward.is_ok(), should_accept, "case {name}");
        match &from_forward {
            Ok((admitted, recomputed)) => {
                assert_eq!(recomputed, &admitted.digests, "case {name}");
            }
            Err(mismatch) => {
                assert_eq!(mismatch.stage, Stage::Digest, "case {name}");
                assert_eq!(mismatch.provenance, name);
            }
        }
    }
}
