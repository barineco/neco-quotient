use std::collections::BTreeMap;

use crate::certificate::ProjectionDigest;
use crate::failure::stage::{Coordinate, Decode, Observations, Residual, Source};
use crate::failure::{ConditionFailure, Origin};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Condition {
    Decode,
    Source,
    Coordinate,
    Observations,
    Digest,
    Residual,
}

impl Condition {
    pub const ALL: [Condition; 6] = [
        Condition::Decode,
        Condition::Source,
        Condition::Coordinate,
        Condition::Observations,
        Condition::Digest,
        Condition::Residual,
    ];

    pub fn name(self) -> &'static str {
        match self {
            Condition::Decode => "decode",
            Condition::Source => "source",
            Condition::Coordinate => "coordinate",
            Condition::Observations => "observations",
            Condition::Digest => "digest",
            Condition::Residual => "residual",
        }
    }

    pub fn prerequisite(self) -> Option<Condition> {
        match self {
            Condition::Decode | Condition::Source => None,
            Condition::Digest => Some(Condition::Decode),
            Condition::Coordinate | Condition::Observations | Condition::Residual => {
                Some(Condition::Source)
            }
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Prerequisite<F, C> {
    Failed(F),
    Established(C),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CheckResult<F> {
    Matched,
    Mismatched(F),
}

impl<F> CheckResult<F> {
    pub fn is_matched(&self) -> bool {
        matches!(self, CheckResult::Matched)
    }

    pub fn failure(&self) -> Option<&F> {
        match self {
            CheckResult::Matched => None,
            CheckResult::Mismatched(failure) => Some(failure),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProjectionResult {
    Matched(ProjectionDigest),
    CertificateOnly(ProjectionDigest),
    RecomputedOnly(ProjectionDigest),
    Different {
        expected: ProjectionDigest,
        actual: ProjectionDigest,
    },
}

impl ProjectionResult {
    pub fn is_matched(&self) -> bool {
        matches!(self, ProjectionResult::Matched(_))
    }
}

pub type DigestChecks = BTreeMap<String, ProjectionResult>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceChecks<P> {
    coordinate: CheckResult<ConditionFailure<Coordinate, P>>,
    observations: CheckResult<ConditionFailure<Observations, P>>,
    residual: CheckResult<ConditionFailure<Residual, P>>,
}

impl<P> SourceChecks<P> {
    pub(crate) fn new(
        coordinate: CheckResult<ConditionFailure<Coordinate, P>>,
        observations: CheckResult<ConditionFailure<Observations, P>>,
        residual: CheckResult<ConditionFailure<Residual, P>>,
    ) -> Self {
        Self {
            coordinate,
            observations,
            residual,
        }
    }

    pub fn coordinate(&self) -> &CheckResult<ConditionFailure<Coordinate, P>> {
        &self.coordinate
    }

    pub fn observations(&self) -> &CheckResult<ConditionFailure<Observations, P>> {
        &self.observations
    }

    pub fn residual(&self) -> &CheckResult<ConditionFailure<Residual, P>> {
        &self.residual
    }

    pub fn all_matched(&self) -> bool {
        self.coordinate.is_matched() && self.observations.is_matched() && self.residual.is_matched()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AdmissionChecks<P> {
    origin: Origin,
    provenance: P,
    decode: Prerequisite<ConditionFailure<Decode, P>, DigestChecks>,
    source: Prerequisite<ConditionFailure<Source, P>, SourceChecks<P>>,
}

impl<P> AdmissionChecks<P> {
    pub(crate) fn new(
        origin: Origin,
        provenance: P,
        decode: Prerequisite<ConditionFailure<Decode, P>, DigestChecks>,
        source: Prerequisite<ConditionFailure<Source, P>, SourceChecks<P>>,
    ) -> Self {
        Self {
            origin,
            provenance,
            decode,
            source,
        }
    }

    pub fn origin(&self) -> &Origin {
        &self.origin
    }

    pub fn provenance(&self) -> &P {
        &self.provenance
    }

    pub fn decode(&self) -> &Prerequisite<ConditionFailure<Decode, P>, DigestChecks> {
        &self.decode
    }

    pub fn source(&self) -> &Prerequisite<ConditionFailure<Source, P>, SourceChecks<P>> {
        &self.source
    }

    pub fn all_matched(&self) -> bool {
        let decode = match &self.decode {
            Prerequisite::Failed(_) => false,
            Prerequisite::Established(digests) => {
                digests.values().all(|result| result.is_matched())
            }
        };
        let source = match &self.source {
            Prerequisite::Failed(_) => false,
            Prerequisite::Established(children) => children.all_matched(),
        };
        decode && source
    }

    pub fn status_at(&self, condition: Condition) -> Status<'_, P> {
        match condition {
            Condition::Decode => match &self.decode {
                Prerequisite::Failed(_) => Status::Mismatched,
                Prerequisite::Established(_) => Status::Matched,
            },
            Condition::Source => match &self.source {
                Prerequisite::Failed(_) => Status::Mismatched,
                Prerequisite::Established(_) => Status::Matched,
            },
            Condition::Digest => match &self.decode {
                Prerequisite::Failed(failure) => Status::UncheckedByDecode(failure),
                Prerequisite::Established(digests) => {
                    Status::of(digests.values().all(|result| result.is_matched()))
                }
            },
            Condition::Coordinate => self.source_child(|children| children.coordinate.is_matched()),
            Condition::Observations => {
                self.source_child(|children| children.observations.is_matched())
            }
            Condition::Residual => self.source_child(|children| children.residual.is_matched()),
        }
    }

    fn source_child(&self, matched: impl FnOnce(&SourceChecks<P>) -> bool) -> Status<'_, P> {
        match &self.source {
            Prerequisite::Failed(failure) => Status::UncheckedBySource(failure),
            Prerequisite::Established(children) => Status::of(matched(children)),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Status<'a, P> {
    Matched,
    Mismatched,
    UncheckedByDecode(&'a ConditionFailure<Decode, P>),
    UncheckedBySource(&'a ConditionFailure<Source, P>),
}

impl<'a, P> Status<'a, P> {
    fn of(matched: bool) -> Self {
        if matched {
            Status::Matched
        } else {
            Status::Mismatched
        }
    }
}
