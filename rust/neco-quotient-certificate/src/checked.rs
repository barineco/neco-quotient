use std::marker::PhantomData;

use crate::certificate::{Certificate, ProjectionDigest, SourceRef};
use crate::rule::RuleTable;

/// 照合を通過した証明書。
///
/// 照合に用いた表を借用し、規則の生存と結ぶ。
#[derive(Debug)]
pub struct Checked<'t, S, Rev, C, Obs, R, E> {
    certificate: Certificate<S, Rev, C, Obs, R, E>,
    recomputed: Vec<ProjectionDigest>,
    _table: PhantomData<&'t RuleTable<S, Rev, C, Obs, E>>,
}

impl<'t, S, Rev, C, Obs, R, E> Checked<'t, S, Rev, C, Obs, R, E> {
    pub(crate) fn new(
        _table: &'t RuleTable<S, Rev, C, Obs, E>,
        certificate: Certificate<S, Rev, C, Obs, R, E>,
        recomputed: Vec<ProjectionDigest>,
    ) -> Self {
        Self {
            certificate,
            recomputed,
            _table: PhantomData,
        }
    }

    pub fn certificate(&self) -> &Certificate<S, Rev, C, Obs, R, E> {
        &self.certificate
    }

    pub fn source(&self) -> &SourceRef<S, Rev> {
        &self.certificate.source
    }

    pub fn recomputed(&self) -> &[ProjectionDigest] {
        &self.recomputed
    }

    pub fn into_certificate(self) -> Certificate<S, Rev, C, Obs, R, E> {
        self.certificate
    }
}
