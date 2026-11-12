use crate::certificate::ResidualSet;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ObservationRefines<D, DPrime, E> {
    pub before_observations: D,
    pub after_observations: DPrime,
    pub evidence: E,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EvaluatedAt<S, B, I, C, D, V, E> {
    pub source: S,
    pub basis: B,
    pub input: I,
    pub certificate: C,
    pub observations: D,
    pub value: V,
    pub evidence: E,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RefinementOutcome<V, R, S> {
    Resolved(V),
    Residual {
        value: V,
        residuals: ResidualSet<R>,
    },
    Stopped {
        value: V,
        residuals: ResidualSet<R>,
        cause: S,
    },
}

impl<V, R, S> RefinementOutcome<V, R, S> {
    fn value(&self) -> &V {
        match self {
            Self::Resolved(value) | Self::Residual { value, .. } | Self::Stopped { value, .. } => {
                value
            }
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedRefinement<S, B, I, C, D, DPrime, V, R, Stop, DR, EB, EA> {
    source: S,
    basis: B,
    input: I,
    certificate: C,
    before_observations: D,
    after_observations: DPrime,
    before: RefinementOutcome<V, R, Stop>,
    after: RefinementOutcome<V, R, Stop>,
    observation_refines: ObservationRefines<D, DPrime, DR>,
    evaluated_before: EvaluatedAt<S, B, I, C, D, V, EB>,
    evaluated_after: EvaluatedAt<S, B, I, C, DPrime, V, EA>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RefinementEvidenceMismatch {
    ObservationRefines,
    EvaluatedBefore,
    EvaluatedAfter,
    DeterminedValueNotPreserved,
}

impl<S, B, I, C, D, DPrime, V, R, Stop, DR, EB, EA>
    VerifiedRefinement<S, B, I, C, D, DPrime, V, R, Stop, DR, EB, EA>
where
    S: PartialEq,
    B: PartialEq,
    I: PartialEq,
    C: PartialEq,
    D: PartialEq,
    DPrime: PartialEq,
    V: PartialEq,
{
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        source: S,
        basis: B,
        input: I,
        certificate: C,
        before_observations: D,
        after_observations: DPrime,
        before: RefinementOutcome<V, R, Stop>,
        after: RefinementOutcome<V, R, Stop>,
        observation_refines: ObservationRefines<D, DPrime, DR>,
        evaluated_before: EvaluatedAt<S, B, I, C, D, V, EB>,
        evaluated_after: EvaluatedAt<S, B, I, C, DPrime, V, EA>,
    ) -> Result<Self, RefinementEvidenceMismatch> {
        if observation_refines.before_observations != before_observations
            || observation_refines.after_observations != after_observations
        {
            return Err(RefinementEvidenceMismatch::ObservationRefines);
        }
        if evaluated_before.source != source
            || evaluated_before.basis != basis
            || evaluated_before.input != input
            || evaluated_before.certificate != certificate
            || evaluated_before.observations != before_observations
            || evaluated_before.value != *before.value()
        {
            return Err(RefinementEvidenceMismatch::EvaluatedBefore);
        }
        if evaluated_after.source != source
            || evaluated_after.basis != basis
            || evaluated_after.input != input
            || evaluated_after.certificate != certificate
            || evaluated_after.observations != after_observations
            || evaluated_after.value != *after.value()
        {
            return Err(RefinementEvidenceMismatch::EvaluatedAfter);
        }
        if let RefinementOutcome::Resolved(before_value) = &before {
            if after.value() != before_value {
                return Err(RefinementEvidenceMismatch::DeterminedValueNotPreserved);
            }
        }
        Ok(Self {
            source,
            basis,
            input,
            certificate,
            before_observations,
            after_observations,
            before,
            after,
            observation_refines,
            evaluated_before,
            evaluated_after,
        })
    }

    pub fn source(&self) -> &S {
        &self.source
    }
    pub fn basis(&self) -> &B {
        &self.basis
    }
    pub fn input(&self) -> &I {
        &self.input
    }
    pub fn certificate(&self) -> &C {
        &self.certificate
    }
    pub fn before_observations(&self) -> &D {
        &self.before_observations
    }
    pub fn after_observations(&self) -> &DPrime {
        &self.after_observations
    }
    pub fn before(&self) -> &RefinementOutcome<V, R, Stop> {
        &self.before
    }
    pub fn after(&self) -> &RefinementOutcome<V, R, Stop> {
        &self.after
    }
    pub fn observation_refines(&self) -> &ObservationRefines<D, DPrime, DR> {
        &self.observation_refines
    }
    pub fn evaluated_before(&self) -> &EvaluatedAt<S, B, I, C, D, V, EB> {
        &self.evaluated_before
    }
    pub fn evaluated_after(&self) -> &EvaluatedAt<S, B, I, C, DPrime, V, EA> {
        &self.evaluated_after
    }
}

#[cfg(test)]
mod tests {
    use super::{
        EvaluatedAt, ObservationRefines, RefinementEvidenceMismatch, RefinementOutcome,
        VerifiedRefinement,
    };
    use crate::ResidualSet;

    type Evidence = VerifiedRefinement<
        &'static str,
        &'static str,
        &'static str,
        &'static str,
        &'static str,
        &'static str,
        u8,
        &'static str,
        &'static str,
        &'static str,
        &'static str,
        &'static str,
    >;

    type EvaluationContext = (
        &'static str,
        &'static str,
        &'static str,
        &'static str,
        &'static str,
    );

    #[allow(clippy::too_many_arguments)]
    fn verified(
        before_observations: &'static str,
        after_observations: &'static str,
        before: RefinementOutcome<u8, &'static str, &'static str>,
        after: RefinementOutcome<u8, &'static str, &'static str>,
        proof_before_observations: &'static str,
        proof_after_observations: &'static str,
        evaluated_before_context: EvaluationContext,
        evaluated_after_context: EvaluationContext,
    ) -> Result<Evidence, RefinementEvidenceMismatch> {
        let before_value = *before.value();
        let after_value = *after.value();
        let (
            before_source,
            before_basis,
            before_input,
            before_certificate,
            evaluated_before_observations,
        ) = evaluated_before_context;
        let (
            after_source,
            after_basis,
            after_input,
            after_certificate,
            evaluated_after_observations,
        ) = evaluated_after_context;
        VerifiedRefinement::new(
            "source",
            "basis",
            "input",
            "certificate",
            before_observations,
            after_observations,
            before,
            after,
            ObservationRefines {
                before_observations: proof_before_observations,
                after_observations: proof_after_observations,
                evidence: "refines-proof",
            },
            EvaluatedAt {
                source: before_source,
                basis: before_basis,
                input: before_input,
                certificate: before_certificate,
                observations: evaluated_before_observations,
                value: before_value,
                evidence: "before-evaluation-proof",
            },
            EvaluatedAt {
                source: after_source,
                basis: after_basis,
                input: after_input,
                certificate: after_certificate,
                observations: evaluated_after_observations,
                value: after_value,
                evidence: "after-evaluation-proof",
            },
        )
    }

    #[test]
    fn resolved_decision_is_preserved_by_the_verified_constructor() {
        let refinement = verified(
            "D",
            "D'",
            RefinementOutcome::Resolved(7),
            RefinementOutcome::Resolved(7),
            "D",
            "D'",
            ("source", "basis", "input", "certificate", "D"),
            ("source", "basis", "input", "certificate", "D'"),
        )
        .expect("the typed evidence names the same inputs and decisions");
        assert_eq!(refinement.source(), &"source");
        assert_eq!(refinement.basis(), &"basis");
        assert_eq!(refinement.input(), &"input");
        assert_eq!(refinement.certificate(), &"certificate");
        assert_eq!(refinement.observation_refines().evidence, "refines-proof");
        assert_eq!(
            refinement.evaluated_before().evidence,
            "before-evaluation-proof"
        );
        assert_eq!(
            refinement.evaluated_after().evidence,
            "after-evaluation-proof"
        );
    }

    #[test]
    fn resolved_value_is_preserved_when_refinement_adds_residuals() {
        let refinement = verified(
            "D",
            "D'",
            RefinementOutcome::Resolved(7),
            RefinementOutcome::Residual {
                value: 7,
                residuals: ResidualSet::new(["additional-coordinate"]),
            },
            "D",
            "D'",
            ("source", "basis", "input", "certificate", "D"),
            ("source", "basis", "input", "certificate", "D'"),
        )
        .expect("the determined value remains while the result carries additional residuals");
        assert!(matches!(
            refinement.after(),
            RefinementOutcome::Residual { value: 7, residuals } if residuals.contains(&"additional-coordinate")
        ));
    }

    #[test]
    fn resolved_value_is_preserved_when_refinement_stops() {
        let refinement = verified(
            "D",
            "D'",
            RefinementOutcome::Resolved(7),
            RefinementOutcome::Stopped {
                value: 7,
                residuals: ResidualSet::new(["additional-coordinate"]),
                cause: "budget",
            },
            "D",
            "D'",
            ("source", "basis", "input", "certificate", "D"),
            ("source", "basis", "input", "certificate", "D'"),
        )
        .expect("the determined value remains while the result carries a stop cause");
        assert!(matches!(
            refinement.after(),
            RefinementOutcome::Stopped {
                value: 7,
                cause: "budget",
                ..
            }
        ));
    }

    #[test]
    fn residual_can_become_resolved_under_refined_observations() {
        let refinement = verified(
            "D",
            "D'",
            RefinementOutcome::Residual {
                value: 0,
                residuals: ResidualSet::new(["coordinate"]),
            },
            RefinementOutcome::Resolved(1),
            "D",
            "D'",
            ("source", "basis", "input", "certificate", "D"),
            ("source", "basis", "input", "certificate", "D'"),
        )
        .expect("a residual result can be resolved by the added observation");
        assert!(matches!(
            refinement.before(),
            RefinementOutcome::Residual { .. }
        ));
        assert!(matches!(refinement.after(), RefinementOutcome::Resolved(1)));
    }

    #[test]
    fn stopped_refinement_retains_residuals_and_cause() {
        let refinement = verified(
            "D",
            "D'",
            RefinementOutcome::Residual {
                value: 0,
                residuals: ResidualSet::new(["coordinate"]),
            },
            RefinementOutcome::Stopped {
                value: 0,
                residuals: ResidualSet::new(["coordinate"]),
                cause: "budget",
            },
            "D",
            "D'",
            ("source", "basis", "input", "certificate", "D"),
            ("source", "basis", "input", "certificate", "D'"),
        )
        .expect("the stop keeps its residual set and cause");
        assert!(matches!(
            refinement.after(),
            RefinementOutcome::Stopped {
                cause: "budget",
                ..
            }
        ));
    }

    #[test]
    fn verified_constructor_rejects_disconnected_references_and_decisions() {
        assert_eq!(
            verified(
                "D",
                "D'",
                RefinementOutcome::Resolved(7),
                RefinementOutcome::Resolved(7),
                "other",
                "D'",
                ("source", "basis", "input", "certificate", "D"),
                ("source", "basis", "input", "certificate", "D'"),
            ),
            Err(RefinementEvidenceMismatch::ObservationRefines),
        );
        assert_eq!(
            verified(
                "D",
                "D'",
                RefinementOutcome::Resolved(7),
                RefinementOutcome::Resolved(8),
                "D",
                "D'",
                ("source", "basis", "input", "certificate", "D"),
                ("source", "basis", "input", "certificate", "D'"),
            ),
            Err(RefinementEvidenceMismatch::DeterminedValueNotPreserved),
        );
        assert_eq!(
            verified(
                "D",
                "D'",
                RefinementOutcome::Resolved(7),
                RefinementOutcome::Residual {
                    value: 8,
                    residuals: ResidualSet::new(["coordinate"]),
                },
                "D",
                "D'",
                ("source", "basis", "input", "certificate", "D"),
                ("source", "basis", "input", "certificate", "D'"),
            ),
            Err(RefinementEvidenceMismatch::DeterminedValueNotPreserved),
        );
        assert_eq!(
            verified(
                "D",
                "D'",
                RefinementOutcome::Resolved(7),
                RefinementOutcome::Stopped {
                    value: 8,
                    residuals: ResidualSet::new(["coordinate"]),
                    cause: "budget",
                },
                "D",
                "D'",
                ("source", "basis", "input", "certificate", "D"),
                ("source", "basis", "input", "certificate", "D'"),
            ),
            Err(RefinementEvidenceMismatch::DeterminedValueNotPreserved),
        );
        assert_eq!(
            verified(
                "D",
                "D'",
                RefinementOutcome::Resolved(7),
                RefinementOutcome::Resolved(7),
                "D",
                "D'",
                ("source", "basis", "input", "certificate", "wrong"),
                ("source", "basis", "input", "certificate", "D'"),
            ),
            Err(RefinementEvidenceMismatch::EvaluatedBefore),
        );
        assert_eq!(
            verified(
                "D",
                "D'",
                RefinementOutcome::Resolved(7),
                RefinementOutcome::Resolved(7),
                "D",
                "D'",
                ("source", "basis", "wrong", "certificate", "D"),
                ("source", "basis", "input", "certificate", "D'"),
            ),
            Err(RefinementEvidenceMismatch::EvaluatedBefore),
        );
    }

    #[test]
    fn verified_constructor_checks_source_basis_and_certificate_references() {
        for before_context in [
            ("other-source", "basis", "input", "certificate", "D"),
            ("source", "other-basis", "input", "certificate", "D"),
            ("source", "basis", "input", "other-certificate", "D"),
        ] {
            assert_eq!(
                verified(
                    "D",
                    "D'",
                    RefinementOutcome::Resolved(7),
                    RefinementOutcome::Resolved(7),
                    "D",
                    "D'",
                    before_context,
                    ("source", "basis", "input", "certificate", "D'"),
                ),
                Err(RefinementEvidenceMismatch::EvaluatedBefore),
            );
        }
        assert_eq!(
            verified(
                "D",
                "D'",
                RefinementOutcome::Resolved(7),
                RefinementOutcome::Resolved(7),
                "D",
                "D'",
                ("source", "basis", "input", "certificate", "D"),
                ("source", "basis", "wrong-input", "certificate", "D'"),
            ),
            Err(RefinementEvidenceMismatch::EvaluatedAfter),
        );
    }
}
