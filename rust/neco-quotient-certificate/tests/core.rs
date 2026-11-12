use std::collections::BTreeMap;

use neco_quotient_certificate::{
    admit, check, AdmissionChecks, CheckResult, Condition, Mismatch, Origin, Prerequisite,
    ProjectionResult, Status,
};

mod model {
    use std::collections::BTreeMap;

    use neco_quotient_certificate::{
        Certificate, DigestScope, Expected, ProjectionDigest, ProjectionDigests, ResidualSet, Rule,
        RuleTable, SourceRef,
    };

    pub(crate) type Source = SourceRef<String, u64>;
    pub(crate) type FixtureCertificate = Certificate<String, u64, u32, u32, u8, u32>;
    pub(crate) type FixtureExpected = Expected<String, u64, u32, u32, u8>;
    pub(crate) type FixtureTable = RuleTable<String, u64, u32, u32, u32>;

    pub(crate) const REVISION: &str = "rule@1";
    pub(crate) const COORDINATE: u32 = 1;
    pub(crate) const OBSERVATIONS: u32 = 3;
    pub(crate) const EVIDENCE: u32 = 5;
    pub(crate) const RESIDUALS: [u8; 1] = [2];

    #[derive(Clone, Copy)]
    pub(crate) struct Semantics {
        salt: &'static str,
    }

    pub(crate) const DEFAULT: Semantics = Semantics { salt: "default" };
    pub(crate) const OTHER: Semantics = Semantics { salt: "other" };

    fn fnv1a(text: &str) -> u64 {
        text.bytes().fold(0xcbf2_9ce4_8422_2325, |hash, byte| {
            (hash ^ u64::from(byte)).wrapping_mul(0x0100_0000_01b3)
        })
    }

    impl Rule<String, u64, u32, u32, u32> for Semantics {
        fn recompute(
            &self,
            source: &Source,
            coordinate: &u32,
            observations: &u32,
            evidence: &u32,
        ) -> ProjectionDigests {
            ["graph", "metadata"]
                .into_iter()
                .map(|projection| {
                    let text = format!(
                        "{}|{}|{}@{}|{}|{}|{}",
                        self.salt,
                        projection,
                        source.identity,
                        source.revision,
                        coordinate,
                        observations,
                        evidence
                    );
                    (
                        projection.to_string(),
                        ProjectionDigest {
                            digest: format!("{:016x}", fnv1a(&text)),
                            scope: DigestScope::CrossLanguage("fnv1a-64".into()),
                        },
                    )
                })
                .collect::<BTreeMap<_, _>>()
        }
    }

    pub(crate) fn source() -> Source {
        SourceRef {
            identity: "src".into(),
            revision: 7,
        }
    }

    pub(crate) fn digests() -> ProjectionDigests {
        DEFAULT.recompute(&source(), &COORDINATE, &OBSERVATIONS, &EVIDENCE)
    }

    pub(crate) fn certificate() -> FixtureCertificate {
        Certificate {
            rule_revision: REVISION.into(),
            source: source(),
            coordinate: COORDINATE,
            digests: digests(),
            residuals: ResidualSet::new(RESIDUALS),
            observations: OBSERVATIONS,
            evidence: EVIDENCE,
        }
    }

    pub(crate) fn expected() -> FixtureExpected {
        Expected {
            rule_revision: REVISION.into(),
            source: source(),
            coordinate: COORDINATE,
            observations: OBSERVATIONS,
            residuals: ResidualSet::new(RESIDUALS),
        }
    }

    pub(crate) fn table() -> FixtureTable {
        table_with(DEFAULT)
    }

    pub(crate) fn table_with(semantics: Semantics) -> FixtureTable {
        let rule: Box<dyn Rule<String, u64, u32, u32, u32> + Send + Sync> = Box::new(semantics);
        RuleTable::new(vec![(REVISION.to_string(), rule)])
            .expect("the fixture table has unique revisions")
    }
}

use model::{
    certificate, digests, expected, source, table, table_with, FixtureCertificate, FixtureTable,
    OTHER,
};

fn word(status: Status<'_, &'static str>) -> &'static str {
    match status {
        Status::Matched => "matched",
        Status::Mismatched => "mismatched",
        Status::UncheckedByDecode(_) | Status::UncheckedBySource(_) => "unchecked",
    }
}

fn statuses(checks: &AdmissionChecks<&'static str>) -> [&'static str; 6] {
    Condition::ALL.map(|condition| word(checks.status_at(condition)))
}

fn rejected(table: &FixtureTable, certificate: FixtureCertificate) -> Mismatch<&'static str> {
    match admit(table, certificate, expected(), "caller") {
        Ok(_) => panic!("the certificate is expected to be rejected"),
        Err(mismatch) => mismatch,
    }
}

fn break_condition(certificate: &mut FixtureCertificate, condition: Condition) {
    match condition {
        Condition::Decode => certificate.rule_revision = "rule@2".into(),
        Condition::Source => certificate.source.revision = 8,
        Condition::Coordinate => certificate.coordinate = 9,
        Condition::Observations => certificate.observations = 9,
        Condition::Digest => certificate.evidence = 6,
        Condition::Residual => {
            certificate.residuals = neco_quotient_certificate::ResidualSet::new([9])
        }
    }
}

mod admission_tests {
    use super::*;

    #[test]
    fn accepted_certificate_builds_checked_with_expected_and_recomputed_map() {
        let table = table();
        let checked =
            admit(&table, certificate(), expected(), "caller").expect("the fixture is admitted");
        assert_eq!(checked.certificate(), &certificate());
        assert_eq!(checked.source(), &source());
        assert_eq!(checked.expected(), &expected());
        assert_eq!(checked.recomputed(), &digests());
        assert_eq!(checked.into_certificate(), certificate());
    }

    #[test]
    fn accepted_certificate_has_every_condition_matched() {
        let checks = check(&table(), &certificate(), &expected(), "caller");
        assert!(checks.all_matched());
        assert_eq!(
            statuses(&checks),
            ["matched", "matched", "matched", "matched", "matched", "matched"]
        );
    }

    #[test]
    fn each_single_break_reports_its_dependent_statuses() {
        let table = table();
        let cases = [
            (
                Condition::Decode,
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
                Condition::Source,
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
                Condition::Coordinate,
                [
                    "matched",
                    "matched",
                    "mismatched",
                    "matched",
                    "mismatched",
                    "matched",
                ],
            ),
            (
                Condition::Observations,
                [
                    "matched",
                    "matched",
                    "matched",
                    "mismatched",
                    "mismatched",
                    "matched",
                ],
            ),
            (
                Condition::Digest,
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
                Condition::Residual,
                [
                    "matched",
                    "matched",
                    "matched",
                    "matched",
                    "matched",
                    "mismatched",
                ],
            ),
        ];
        for (condition, expected_statuses) in cases {
            let mut certificate = certificate();
            break_condition(&mut certificate, condition);
            let mismatch = rejected(&table, certificate);
            assert_eq!(
                statuses(mismatch.checks()),
                expected_statuses,
                "{condition:?}"
            );
        }
    }

    #[test]
    fn simultaneous_root_failures_are_both_reported_and_their_children_unchecked() {
        let table = table();
        let mut certificate = certificate();
        break_condition(&mut certificate, Condition::Decode);
        break_condition(&mut certificate, Condition::Source);
        let mismatch = rejected(&table, certificate);
        assert_eq!(
            statuses(mismatch.checks()),
            [
                "mismatched",
                "mismatched",
                "unchecked",
                "unchecked",
                "unchecked",
                "unchecked"
            ]
        );
        let Status::UncheckedByDecode(decode) = mismatch.status_at(Condition::Digest) else {
            panic!("digest is unchecked by decode");
        };
        assert_eq!(decode.expected, "rule@1");
        assert_eq!(decode.actual, "rule@2");
        let Status::UncheckedBySource(source) = mismatch.status_at(Condition::Coordinate) else {
            panic!("coordinate is unchecked by source");
        };
        assert_eq!(source.expected, "src@7");
        assert_eq!(source.actual, "src@8");
    }

    #[test]
    fn simultaneous_independent_children_are_all_reported() {
        let table = table();
        let mut certificate = certificate();
        break_condition(&mut certificate, Condition::Coordinate);
        break_condition(&mut certificate, Condition::Observations);
        break_condition(&mut certificate, Condition::Residual);
        let mismatch = rejected(&table, certificate);
        assert_eq!(
            statuses(mismatch.checks()),
            [
                "matched",
                "matched",
                "mismatched",
                "mismatched",
                "mismatched",
                "mismatched"
            ]
        );
    }

    #[test]
    fn one_sided_projection_keys_are_classified_by_name() {
        let table = table();
        let mut certificate = certificate();
        certificate.digests.remove("metadata");
        certificate.digests.insert(
            "extra".into(),
            neco_quotient_certificate::ProjectionDigest {
                digest: "0".repeat(16),
                scope: neco_quotient_certificate::DigestScope::CrossLanguage("fnv1a-64".into()),
            },
        );
        let mismatch = rejected(&table, certificate);
        let results = digest_results(&mismatch);
        assert!(matches!(
            results.get("graph"),
            Some(ProjectionResult::Matched(_))
        ));
        assert!(matches!(
            results.get("metadata"),
            Some(ProjectionResult::RecomputedOnly(_))
        ));
        assert!(matches!(
            results.get("extra"),
            Some(ProjectionResult::CertificateOnly(_))
        ));
        assert_eq!(results.len(), 3);
    }

    #[test]
    fn scope_and_value_differences_are_classified_as_different_per_name() {
        let table = table();
        let mut certificate = certificate();
        certificate
            .digests
            .get_mut("graph")
            .expect("graph is present")
            .scope = neco_quotient_certificate::DigestScope::WithinRuntime("rust".into());
        certificate
            .digests
            .get_mut("metadata")
            .expect("metadata is present")
            .digest = "x".repeat(16);
        let mismatch = rejected(&table, certificate);
        let results = digest_results(&mismatch);
        let Some(ProjectionResult::Different { expected, actual }) = results.get("graph") else {
            panic!("graph differs in scope");
        };
        assert_eq!(
            expected.scope,
            neco_quotient_certificate::DigestScope::CrossLanguage("fnv1a-64".into())
        );
        assert_eq!(
            actual.scope,
            neco_quotient_certificate::DigestScope::WithinRuntime("rust".into())
        );
        assert!(matches!(
            results.get("metadata"),
            Some(ProjectionResult::Different { .. })
        ));
    }

    #[test]
    fn changing_one_name_leaves_the_result_of_another_name_unchanged() {
        let table = table();
        let mut certificate = certificate();
        certificate
            .digests
            .get_mut("metadata")
            .expect("metadata is present")
            .digest = "x".repeat(16);
        let mismatch = rejected(&table, certificate);
        let results = digest_results(&mismatch);
        assert!(matches!(
            results.get("graph"),
            Some(ProjectionResult::Matched(_))
        ));
        assert!(matches!(
            results.get("metadata"),
            Some(ProjectionResult::Different { .. })
        ));
    }

    #[test]
    fn digest_map_insertion_order_does_not_change_the_outcome() {
        let table = table();
        let base = digests();
        let mut reversed = BTreeMap::new();
        for (name, digest) in base.iter().rev() {
            reversed.insert(name.clone(), digest.clone());
        }
        let mut forward_certificate = certificate();
        forward_certificate.digests = base;
        let mut reversed_certificate = certificate();
        reversed_certificate.digests = reversed;

        assert_eq!(
            check(&table, &forward_certificate, &expected(), "caller"),
            check(&table, &reversed_certificate, &expected(), "caller")
        );
        assert!(admit(&table, forward_certificate, expected(), "caller").is_ok());
        assert!(admit(&table, reversed_certificate, expected(), "caller").is_ok());
    }

    #[test]
    fn check_agrees_with_admit_for_each_breakage() {
        let table = table();
        for condition in Condition::ALL {
            let mut certificate = certificate();
            break_condition(&mut certificate, condition);
            let checks = check(&table, &certificate, &expected(), "caller");
            match admit(&table, certificate, expected(), "caller") {
                Ok(_) => assert!(checks.all_matched(), "{condition:?}"),
                Err(mismatch) => {
                    assert!(!checks.all_matched(), "{condition:?}");
                    assert_eq!(mismatch.checks(), &checks, "{condition:?}");
                }
            }
        }
    }

    #[test]
    fn residuals_are_compared_as_a_set() {
        let table = table();
        let mut certificate = certificate();
        certificate.residuals = neco_quotient_certificate::ResidualSet::new([2, 2]);
        let checked = admit(&table, certificate, expected(), "caller");
        assert!(checked.is_ok());
    }

    #[test]
    fn provenance_and_origin_are_kept_by_each_failure() {
        let table = table();
        let mut certificate = certificate();
        certificate.rule_revision = "rule@2".into();
        certificate.source.identity = "other".into();
        break_condition(&mut certificate, Condition::Coordinate);
        let mismatch = rejected(&table, certificate);
        let origin = Origin {
            rule_revision: "rule@2".into(),
            source_identity: "other".into(),
            source_revision: "7".into(),
        };
        assert_eq!(mismatch.origin(), &origin);
        assert_eq!(mismatch.provenance(), &"caller");

        let Prerequisite::Failed(decode) = mismatch.checks().decode() else {
            panic!("decode fails");
        };
        assert_eq!(decode.origin, origin);
        assert_eq!(decode.provenance, "caller");
        assert_eq!(decode.condition(), Condition::Decode);

        let Prerequisite::Failed(source) = mismatch.checks().source() else {
            panic!("source fails");
        };
        assert_eq!(source.origin, origin);
        assert_eq!(source.provenance, "caller");
        assert_eq!(source.expected, "src@7");
        assert_eq!(source.actual, "other@7");

        let Status::UncheckedByDecode(digest) = mismatch.status_at(Condition::Digest) else {
            panic!("digest is unchecked by decode");
        };
        assert_eq!(digest.origin, origin);
        assert_eq!(digest.provenance, "caller");

        let Status::UncheckedBySource(coordinate) = mismatch.status_at(Condition::Coordinate)
        else {
            panic!("coordinate is unchecked by source");
        };
        assert_eq!(coordinate.origin, origin);
        assert_eq!(coordinate.provenance, "caller");
    }

    #[test]
    fn mismatch_is_an_error_when_its_provenance_is_debug() {
        fn assert_error<E: std::error::Error>(_: &E) {}
        let mismatch = rejected(&table_with(OTHER), certificate());
        assert_error(&mismatch);
    }

    #[test]
    fn unregistered_revision_is_reported_at_decode_when_versions_agree() {
        let table = table();
        let mut certificate = certificate();
        certificate.rule_revision = "rule@9".into();
        let mut expected = expected();
        expected.rule_revision = "rule@9".into();
        let mismatch = match admit(&table, certificate, expected, "caller") {
            Ok(_) => panic!("an unregistered revision is rejected"),
            Err(mismatch) => mismatch,
        };
        let Prerequisite::Failed(decode) = mismatch.checks().decode() else {
            panic!("decode fails");
        };
        assert_eq!(decode.expected, "rule in table");
        assert_eq!(decode.actual, "rule@9");
    }

    #[test]
    fn same_revision_with_other_rule_semantics_is_rejected_at_digest_alone() {
        let table = table_with(OTHER);
        let mismatch = rejected(&table, certificate());
        assert_eq!(
            statuses(mismatch.checks()),
            [
                "matched",
                "matched",
                "matched",
                "matched",
                "mismatched",
                "matched"
            ]
        );
        let results = digest_results(&mismatch);
        assert!(matches!(
            results.get("graph"),
            Some(ProjectionResult::Different { .. })
        ));
        assert!(matches!(
            results.get("metadata"),
            Some(ProjectionResult::Different { .. })
        ));
    }

    #[test]
    fn mismatch_display_names_the_failed_conditions_and_origin() {
        let table = table();
        let mut certificate = certificate();
        certificate.rule_revision = "rule@2".into();
        certificate.source.identity = "other".into();
        let mismatch = rejected(&table, certificate);
        let text = mismatch.to_string();
        assert!(
            text.starts_with("admit failed at decode, source:"),
            "{text}"
        );
        assert!(text.contains("rule rule@2"), "{text}");
        assert!(text.contains("source other@7"), "{text}");
    }

    fn digest_results(mismatch: &Mismatch<&'static str>) -> BTreeMap<String, ProjectionResult> {
        match mismatch.checks().decode() {
            Prerequisite::Established(results) => results.clone(),
            Prerequisite::Failed(_) => panic!("the digest is checked after decode"),
        }
    }

    #[test]
    fn source_children_results_are_read_through_accessors() {
        let table = table();
        let mut certificate = certificate();
        break_condition(&mut certificate, Condition::Residual);
        let mismatch = rejected(&table, certificate);
        let Prerequisite::Established(children) = mismatch.checks().source() else {
            panic!("source is established");
        };
        assert!(children.coordinate().is_matched());
        assert!(children.observations().is_matched());
        assert!(matches!(children.residual(), CheckResult::Mismatched(_)));
        assert!(!children.all_matched());
    }
}
