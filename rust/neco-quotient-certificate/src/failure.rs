use std::fmt;
use std::marker::PhantomData;

use crate::checks::{AdmissionChecks, Condition, Status};

const OPERATION: &str = "admit";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Origin {
    pub rule_revision: String,
    pub source_identity: String,
    pub source_revision: String,
}

pub mod stage {
    use crate::checks::Condition;

    pub trait Stage {
        const CONDITION: Condition;
    }

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    pub struct Decode;

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    pub struct Source;

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    pub struct Coordinate;

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    pub struct Observations;

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    pub struct Residual;

    impl Stage for Decode {
        const CONDITION: Condition = Condition::Decode;
    }

    impl Stage for Source {
        const CONDITION: Condition = Condition::Source;
    }

    impl Stage for Coordinate {
        const CONDITION: Condition = Condition::Coordinate;
    }

    impl Stage for Observations {
        const CONDITION: Condition = Condition::Observations;
    }

    impl Stage for Residual {
        const CONDITION: Condition = Condition::Residual;
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConditionFailure<St, P> {
    pub operation: &'static str,
    pub expected: String,
    pub actual: String,
    pub origin: Origin,
    pub provenance: P,
    _stage: PhantomData<St>,
}

impl<St, P> ConditionFailure<St, P> {
    pub(crate) fn new(expected: String, actual: String, origin: &Origin, provenance: &P) -> Self
    where
        P: Clone,
    {
        Self {
            operation: OPERATION,
            expected,
            actual,
            origin: origin.clone(),
            provenance: provenance.clone(),
            _stage: PhantomData,
        }
    }
}

impl<St: stage::Stage, P> ConditionFailure<St, P> {
    pub fn condition(&self) -> Condition {
        St::CONDITION
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Mismatch<P> {
    checks: AdmissionChecks<P>,
}

impl<P> Mismatch<P> {
    pub(crate) fn new(checks: AdmissionChecks<P>) -> Self {
        debug_assert!(!checks.all_matched());
        Self { checks }
    }

    pub fn checks(&self) -> &AdmissionChecks<P> {
        &self.checks
    }

    pub fn status_at(&self, condition: Condition) -> Status<'_, P> {
        self.checks.status_at(condition)
    }

    pub fn origin(&self) -> &Origin {
        self.checks.origin()
    }

    pub fn provenance(&self) -> &P {
        self.checks.provenance()
    }
}

impl<P> fmt::Display for Mismatch<P> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let failed: Vec<&str> = Condition::ALL
            .into_iter()
            .filter(|condition| matches!(self.status_at(*condition), Status::Mismatched))
            .map(Condition::name)
            .collect();
        let origin = self.origin();
        write!(
            f,
            "{} failed at {}: rule {}, source {}@{}",
            OPERATION,
            failed.join(", "),
            origin.rule_revision,
            origin.source_identity,
            origin.source_revision,
        )
    }
}

impl<P: fmt::Debug> std::error::Error for Mismatch<P> {}
