use neco_quotient_certificate::admit;

mod model {
    use neco_quotient_certificate::{
        Certificate, DigestScope, Expected, ProjectionDigest, ResidualSet, Rule, RuleTable,
        SourceRef, Stage,
    };

    pub(crate) type Source = SourceRef<String, u64>;
    pub(crate) type FixtureCertificate = Certificate<String, u64, u32, u32, u8, u32>;
    pub(crate) type FixtureExpected = Expected<String, u64, u32, u32, u8>;
    pub(crate) type FixtureTable = RuleTable<String, u64, u32, u32, u32>;

    pub(crate) const REVISION: &str = "rule@1";
    pub(crate) const STAGES: [Stage; 6] = [
        Stage::Decode,
        Stage::Source,
        Stage::Coordinate,
        Stage::Observations,
        Stage::Digest,
        Stage::Residual,
    ];

    const COORDINATE: u32 = 1;
    const OBSERVATIONS: u32 = 3;
    const EVIDENCE: u32 = 5;
    const RESIDUALS: [u8; 1] = [2];

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
        ) -> Vec<ProjectionDigest> {
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
                    ProjectionDigest {
                        projection: projection.to_string(),
                        digest: format!("{:016x}", fnv1a(&text)),
                        scope: DigestScope::CrossLanguage("fnv1a-64".into()),
                    }
                })
                .collect()
        }
    }

    pub(crate) fn source() -> Source {
        SourceRef {
            identity: "src".into(),
            revision: 7,
        }
    }

    pub(crate) fn digests() -> Vec<ProjectionDigest> {
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

    pub(crate) fn break_stage(certificate: &mut FixtureCertificate, stage: Stage) {
        match stage {
            Stage::Decode => certificate.rule_revision = "rule@2".into(),
            Stage::Source => certificate.source.revision = 8,
            Stage::Coordinate => certificate.coordinate = 9,
            Stage::Observations => certificate.observations = 9,
            Stage::Digest => {
                certificate.digests = OTHER.recompute(
                    &certificate.source,
                    &certificate.coordinate,
                    &certificate.observations,
                    &certificate.evidence,
                )
            }
            Stage::Residual => certificate.residuals = ResidualSet::new([9]),
        }
    }
}

mod admission_tests {

    use super::admit;
    use crate::model::{
        break_stage, certificate, expected, source, table, table_with, FixtureCertificate,
        FixtureExpected, FixtureTable, OTHER, STAGES,
    };
    use neco_quotient_certificate::Rule;
    use neco_quotient_certificate::{Mismatch, Stage};

    fn failure(
        table: &FixtureTable,
        certificate: FixtureCertificate,
        expected: &FixtureExpected,
    ) -> Mismatch<&'static str> {
        match admit(table, certificate, expected, "caller") {
            Ok(_) => panic!("the certificate is expected to be rejected"),
            Err(mismatch) => mismatch,
        }
    }

    #[test]
    fn each_stage_is_reported_before_all_later_stages() {
        let table = table();
        for (index, stage) in STAGES.iter().enumerate() {
            let mut certificate = certificate();
            for later in &STAGES[index..] {
                break_stage(&mut certificate, *later);
            }
            let mismatch = failure(&table, certificate, &expected());
            assert_eq!(mismatch.stage, *stage);
        }
    }

    #[test]
    fn each_stage_alone_is_reported_at_that_stage() {
        let table = table();
        for stage in STAGES {
            let mut certificate = certificate();
            break_stage(&mut certificate, stage);
            let mismatch = failure(&table, certificate, &expected());
            assert_eq!(mismatch.stage, stage);
        }
    }

    #[test]
    fn version_mismatch_is_reported_before_unknown_revision() {
        let table = table();
        let mut certificate = certificate();
        certificate.rule_revision = "rule@2".into();
        let mismatch = failure(&table, certificate, &expected());
        assert_eq!(mismatch.stage, Stage::Decode);
        assert_eq!(mismatch.expected, "rule@1");
        assert_eq!(mismatch.actual, "rule@2");
    }

    #[test]
    fn unknown_revision_is_reported_at_decode_when_versions_agree() {
        let table = table();
        let mut certificate = certificate();
        certificate.rule_revision = "rule@9".into();
        let mut expected = expected();
        expected.rule_revision = "rule@9".into();
        let mismatch = failure(&table, certificate, &expected);
        assert_eq!(mismatch.stage, Stage::Decode);
        assert_eq!(mismatch.expected, "rule in table");
        assert_eq!(mismatch.actual, "rule@9");
    }

    #[test]
    fn origin_is_taken_from_the_certificate_and_provenance_is_kept() {
        let table = table();
        let mut certificate = certificate();
        certificate.rule_revision = "rule@2".into();
        certificate.source.identity = "other".into();
        let mismatch = failure(&table, certificate, &expected());
        assert_eq!(mismatch.stage, Stage::Decode);
        assert_eq!(mismatch.provenance, "caller");
        assert_eq!(mismatch.origin.rule_revision, "rule@2");
        assert_eq!(mismatch.origin.source_identity, "other");
        assert_eq!(mismatch.origin.source_revision, "7");
        assert!(mismatch.contributing.is_empty());
    }

    #[test]
    fn source_origin_is_taken_from_the_certificate() {
        let table = table();
        let mut certificate = certificate();
        certificate.source.identity = "other".into();
        certificate.source.revision = 11;
        let mismatch = failure(&table, certificate, &expected());
        assert_eq!(mismatch.stage, Stage::Source);
        assert_eq!(mismatch.expected, "src@7");
        assert_eq!(mismatch.actual, "other@11");
        assert_eq!(mismatch.origin.rule_revision, "rule@1");
        assert_eq!(mismatch.origin.source_identity, "other");
        assert_eq!(mismatch.origin.source_revision, "11");
        assert_eq!(mismatch.provenance, "caller");
    }

    #[test]
    fn mismatch_display_names_operation_stage_and_origin() {
        let table = table();
        let mut certificate = certificate();
        break_stage(&mut certificate, Stage::Residual);
        let mismatch = failure(&table, certificate, &expected());
        let text = mismatch.to_string();
        assert!(text.starts_with("admit failed at stage residual"), "{text}");
        assert!(text.contains("rule rule@1"), "{text}");
        assert!(text.contains("source src@7"), "{text}");
    }

    #[test]
    fn evidence_change_alone_is_rejected_at_digest() {
        let table = table();
        let mut certificate = certificate();
        certificate.evidence = 6;
        let mismatch = failure(&table, certificate, &expected());
        assert_eq!(mismatch.stage, Stage::Digest);
    }

    #[test]
    fn same_revision_with_other_rule_semantics_is_rejected_at_digest() {
        let table = table_with(OTHER);
        let mismatch = failure(&table, certificate(), &expected());
        assert_eq!(mismatch.stage, Stage::Digest);
        let recomputed = OTHER.recompute(&source(), &1, &3, &5);
        assert_eq!(mismatch.expected, format!("{:?}", recomputed));
    }
}

mod checked_tests {

    use crate::model::{certificate, digests, expected, source, table};
    use neco_quotient_certificate::admit;

    #[test]
    fn admitted_value_exposes_certificate_source_and_recomputed_digests() {
        let table = table();
        let checked = admit(&table, certificate(), &expected(), "caller")
            .expect("the fixture certificate is admitted");

        assert_eq!(checked.certificate(), &certificate());
        assert_eq!(checked.source(), &source());
        assert_eq!(checked.recomputed(), digests().as_slice());
        assert_eq!(checked.into_certificate(), certificate());
    }
}
