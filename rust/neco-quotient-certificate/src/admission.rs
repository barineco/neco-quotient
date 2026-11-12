use std::collections::BTreeSet;
use std::fmt::{Debug, Display};

use crate::certificate::{Certificate, Expected, ProjectionDigests, SourceRef};
use crate::checked::Checked;
use crate::checks::{
    AdmissionChecks, CheckResult, DigestChecks, Prerequisite, ProjectionResult, SourceChecks,
};
use crate::failure::stage::{Coordinate, Decode, Observations, Residual, Source};
use crate::failure::{ConditionFailure, Mismatch, Origin};
use crate::rule::{Rule, RuleTable};

const TABLE_EXPECTATION: &str = "rule in table";

#[allow(clippy::result_large_err, clippy::type_complexity)]
pub fn admit<'t, S, Rev, C, Obs, R, E, P>(
    table: &'t RuleTable<S, Rev, C, Obs, E>,
    certificate: Certificate<S, Rev, C, Obs, R, E>,
    expected: Expected<S, Rev, C, Obs, R>,
    provenance: P,
) -> Result<Checked<'t, S, Rev, C, Obs, R, E>, Mismatch<P>>
where
    S: Eq + Display,
    Rev: Eq + Display,
    C: Eq + Debug,
    Obs: Eq + Debug,
    R: Eq + Debug,
    P: Clone,
{
    let (checks, recomputed) = evaluate(table, &certificate, &expected, provenance);
    match recomputed {
        Some(recomputed) if checks.all_matched() => {
            Ok(Checked::new(table, certificate, expected, recomputed))
        }
        _ => Err(Mismatch::new(checks)),
    }
}

pub fn check<S, Rev, C, Obs, R, E, P>(
    table: &RuleTable<S, Rev, C, Obs, E>,
    certificate: &Certificate<S, Rev, C, Obs, R, E>,
    expected: &Expected<S, Rev, C, Obs, R>,
    provenance: P,
) -> AdmissionChecks<P>
where
    S: Eq + Display,
    Rev: Eq + Display,
    C: Eq + Debug,
    Obs: Eq + Debug,
    R: Eq + Debug,
    P: Clone,
{
    evaluate(table, certificate, expected, provenance).0
}

fn evaluate<S, Rev, C, Obs, R, E, P>(
    table: &RuleTable<S, Rev, C, Obs, E>,
    certificate: &Certificate<S, Rev, C, Obs, R, E>,
    expected: &Expected<S, Rev, C, Obs, R>,
    provenance: P,
) -> (AdmissionChecks<P>, Option<ProjectionDigests>)
where
    S: Eq + Display,
    Rev: Eq + Display,
    C: Eq + Debug,
    Obs: Eq + Debug,
    R: Eq + Debug,
    P: Clone,
{
    let origin = origin_of(certificate);
    let (decode, recomputed) = match select_rule(table, certificate, expected, &origin, &provenance)
    {
        Err(failure) => (Prerequisite::Failed(failure), None),
        Ok(rule) => {
            let recomputed = rule.recompute(
                &certificate.source,
                &certificate.coordinate,
                &certificate.observations,
                &certificate.evidence,
            );
            let digests = compare_digests(&recomputed, &certificate.digests);
            (Prerequisite::Established(digests), Some(recomputed))
        }
    };
    let source = source_branch(certificate, expected, &origin, &provenance);
    (
        AdmissionChecks::new(origin, provenance, decode, source),
        recomputed,
    )
}

fn origin_of<S, Rev, C, Obs, R, E>(certificate: &Certificate<S, Rev, C, Obs, R, E>) -> Origin
where
    S: Display,
    Rev: Display,
{
    Origin {
        rule_revision: certificate.rule_revision.clone(),
        source_identity: certificate.source.identity.to_string(),
        source_revision: certificate.source.revision.to_string(),
    }
}

#[allow(clippy::result_large_err)]
fn select_rule<'t, S, Rev, C, Obs, R, E, P>(
    table: &'t RuleTable<S, Rev, C, Obs, E>,
    certificate: &Certificate<S, Rev, C, Obs, R, E>,
    expected: &Expected<S, Rev, C, Obs, R>,
    origin: &Origin,
    provenance: &P,
) -> Result<&'t (dyn Rule<S, Rev, C, Obs, E> + Send + Sync), ConditionFailure<Decode, P>>
where
    P: Clone,
{
    if certificate.rule_revision != expected.rule_revision {
        return Err(ConditionFailure::new(
            expected.rule_revision.clone(),
            certificate.rule_revision.clone(),
            origin,
            provenance,
        ));
    }
    table.lookup(&certificate.rule_revision).ok_or_else(|| {
        ConditionFailure::new(
            TABLE_EXPECTATION.to_string(),
            certificate.rule_revision.clone(),
            origin,
            provenance,
        )
    })
}

fn compare_digests(
    recomputed: &ProjectionDigests,
    certificate: &ProjectionDigests,
) -> DigestChecks {
    let names: BTreeSet<&str> = recomputed
        .keys()
        .chain(certificate.keys())
        .map(String::as_str)
        .collect();
    let mut checks = DigestChecks::new();
    for name in names {
        let result = match (recomputed.get(name), certificate.get(name)) {
            (Some(expected), Some(actual)) if expected == actual => {
                ProjectionResult::Matched(expected.clone())
            }
            (Some(expected), Some(actual)) => ProjectionResult::Different {
                expected: expected.clone(),
                actual: actual.clone(),
            },
            (Some(expected), None) => ProjectionResult::RecomputedOnly(expected.clone()),
            (None, Some(actual)) => ProjectionResult::CertificateOnly(actual.clone()),
            (None, None) => continue,
        };
        checks.insert(name.to_string(), result);
    }
    checks
}

fn source_branch<S, Rev, C, Obs, R, E, P>(
    certificate: &Certificate<S, Rev, C, Obs, R, E>,
    expected: &Expected<S, Rev, C, Obs, R>,
    origin: &Origin,
    provenance: &P,
) -> Prerequisite<ConditionFailure<Source, P>, SourceChecks<P>>
where
    S: Eq + Display,
    Rev: Eq + Display,
    C: Eq + Debug,
    Obs: Eq + Debug,
    R: Eq + Debug,
    P: Clone,
{
    if certificate.source != expected.source {
        return Prerequisite::Failed(ConditionFailure::new(
            source_text(&expected.source),
            source_text(&certificate.source),
            origin,
            provenance,
        ));
    }
    Prerequisite::Established(SourceChecks::new(
        condition_result(certificate.coordinate == expected.coordinate, || {
            ConditionFailure::<Coordinate, P>::new(
                format!("{:?}", expected.coordinate),
                format!("{:?}", certificate.coordinate),
                origin,
                provenance,
            )
        }),
        condition_result(certificate.observations == expected.observations, || {
            ConditionFailure::<Observations, P>::new(
                format!("{:?}", expected.observations),
                format!("{:?}", certificate.observations),
                origin,
                provenance,
            )
        }),
        condition_result(certificate.residuals == expected.residuals, || {
            ConditionFailure::<Residual, P>::new(
                format!("{:?}", expected.residuals),
                format!("{:?}", certificate.residuals),
                origin,
                provenance,
            )
        }),
    ))
}

fn condition_result<F>(holds: bool, failure: impl FnOnce() -> F) -> CheckResult<F> {
    if holds {
        CheckResult::Matched
    } else {
        CheckResult::Mismatched(failure())
    }
}

fn source_text<S: Display, Rev: Display>(source: &SourceRef<S, Rev>) -> String {
    format!("{}@{}", source.identity, source.revision)
}
