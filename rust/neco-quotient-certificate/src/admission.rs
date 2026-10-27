use std::fmt::{Debug, Display};

use crate::certificate::{Certificate, Expected, SourceRef};
use crate::checked::Checked;
use crate::failure::{Mismatch, Origin, Stage};
use crate::rule::RuleTable;

const OPERATION: &str = "admit";
const TABLE_EXPECTATION: &str = "rule in table";

/// 証明書を期待値と照合する。照合は、リビジョン、入力参照、座標、観測、射影ダイジェスト、残余の順に段階を検査する。
/// decode ではリビジョンの比較を表の検索より先に行う。
#[allow(clippy::result_large_err, clippy::type_complexity)]
pub fn admit<'t, S, Rev, C, Obs, R, E, P>(
    table: &'t RuleTable<S, Rev, C, Obs, E>,
    certificate: Certificate<S, Rev, C, Obs, R, E>,
    expected: &Expected<S, Rev, C, Obs, R>,
    provenance: P,
) -> Result<Checked<'t, S, Rev, C, Obs, R, E>, Mismatch<P>>
where
    S: Eq + Display,
    Rev: Eq + Display,
    C: Eq + Debug,
    Obs: Eq + Debug,
    R: Eq + Debug,
{
    if certificate.rule_revision != expected.rule_revision {
        return Err(mismatch(
            &certificate,
            Stage::Decode,
            expected.rule_revision.clone(),
            certificate.rule_revision.clone(),
            provenance,
        ));
    }
    let Some(rule) = table.lookup(&certificate.rule_revision) else {
        return Err(mismatch(
            &certificate,
            Stage::Decode,
            TABLE_EXPECTATION.to_string(),
            certificate.rule_revision.clone(),
            provenance,
        ));
    };
    if certificate.source != expected.source {
        return Err(mismatch(
            &certificate,
            Stage::Source,
            source_text(&expected.source),
            source_text(&certificate.source),
            provenance,
        ));
    }
    if certificate.coordinate != expected.coordinate {
        return Err(mismatch(
            &certificate,
            Stage::Coordinate,
            format!("{:?}", expected.coordinate),
            format!("{:?}", certificate.coordinate),
            provenance,
        ));
    }
    if certificate.observations != expected.observations {
        return Err(mismatch(
            &certificate,
            Stage::Observations,
            format!("{:?}", expected.observations),
            format!("{:?}", certificate.observations),
            provenance,
        ));
    }
    let recomputed = rule.recompute(
        &certificate.source,
        &certificate.coordinate,
        &certificate.observations,
        &certificate.evidence,
    );
    if certificate.digests != recomputed {
        return Err(mismatch(
            &certificate,
            Stage::Digest,
            format!("{:?}", recomputed),
            format!("{:?}", certificate.digests),
            provenance,
        ));
    }
    if certificate.residuals != expected.residuals {
        return Err(mismatch(
            &certificate,
            Stage::Residual,
            format!("{:?}", expected.residuals),
            format!("{:?}", certificate.residuals),
            provenance,
        ));
    }
    Ok(Checked::new(table, certificate, recomputed))
}

fn source_text<S: Display, Rev: Display>(source: &SourceRef<S, Rev>) -> String {
    format!("{}@{}", source.identity, source.revision)
}

fn mismatch<S, Rev, C, Obs, R, E, P>(
    certificate: &Certificate<S, Rev, C, Obs, R, E>,
    stage: Stage,
    expected: String,
    actual: String,
    provenance: P,
) -> Mismatch<P>
where
    S: Display,
    Rev: Display,
{
    Mismatch {
        operation: OPERATION,
        stage,
        expected,
        actual,
        origin: Origin {
            rule_revision: certificate.rule_revision.clone(),
            source_identity: certificate.source.identity.to_string(),
            source_revision: certificate.source.revision.to_string(),
        },
        provenance,
        contributing: Vec::new(),
    }
}
