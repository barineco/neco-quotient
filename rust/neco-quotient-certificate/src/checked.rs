use std::marker::PhantomData;

use crate::certificate::{Certificate, Expected, ProjectionDigests, SourceRef};
use crate::rule::RuleTable;

#[derive(Debug)]
pub struct Checked<'t, S, Rev, C, Obs, R, E> {
    certificate: Certificate<S, Rev, C, Obs, R, E>,
    expected: Expected<S, Rev, C, Obs, R>,
    recomputed: ProjectionDigests,
    _table: PhantomData<&'t RuleTable<S, Rev, C, Obs, E>>,
}

impl<'t, S, Rev, C, Obs, R, E> Checked<'t, S, Rev, C, Obs, R, E> {
    pub(crate) fn new(
        _table: &'t RuleTable<S, Rev, C, Obs, E>,
        certificate: Certificate<S, Rev, C, Obs, R, E>,
        expected: Expected<S, Rev, C, Obs, R>,
        recomputed: ProjectionDigests,
    ) -> Self {
        Self {
            certificate,
            expected,
            recomputed,
            _table: PhantomData,
        }
    }

    pub fn certificate(&self) -> &Certificate<S, Rev, C, Obs, R, E> {
        &self.certificate
    }

    pub fn expected(&self) -> &Expected<S, Rev, C, Obs, R> {
        &self.expected
    }

    pub fn source(&self) -> &SourceRef<S, Rev> {
        &self.certificate.source
    }

    pub fn recomputed(&self) -> &ProjectionDigests {
        &self.recomputed
    }

    pub fn into_certificate(self) -> Certificate<S, Rev, C, Obs, R, E> {
        self.certificate
    }
}
