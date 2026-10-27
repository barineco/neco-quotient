#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LiveSet<I, B> {
    pub active_bases: Vec<B>,
    pub branch_roots: Vec<I>,
    pub future_uses: Vec<I>,
    pub outstanding_effects: Vec<I>,
    pub outstanding_signals: Vec<I>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Recoverability<K, W> {
    Source(K),
    Checkpoint { checkpoint: K, witness: W },
    Replay { derivation: W },
    ExternalReobservation,
    Irrecoverable,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ErasureRequest<I, B, O> {
    pub target: I,
    pub target_basis: Option<B>,
    pub removed_observations: Vec<O>,
    pub preserved_observations: Vec<O>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RetentionReason<I, B, O> {
    ActiveBasis(B),
    BranchRoot(I),
    FutureUse(I),
    OutstandingEffect(I),
    OutstandingSignal(I),
    ExternalReobservation,
    ObservationNotPreserved(O),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MissingInput {
    RemovedObservationsUndeclared,
    RecoverabilityUnknown,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DematerializeWitness<I, K, W, O> {
    pub target: I,
    pub recoverability: Recoverability<K, W>,
    pub removed_observations: Vec<O>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ErasureDecision<I, B, K, W, O> {
    Dematerialize(DematerializeWitness<I, K, W, O>),
    Retain(Vec<RetentionReason<I, B, O>>),
    Rejected(MissingInput),
}

pub fn judge_erasure<I: Eq + Clone, B: Eq + Clone, K, W, O: Eq + Clone>(
    request: ErasureRequest<I, B, O>,
    live: &LiveSet<I, B>,
    recoverability: Option<Recoverability<K, W>>,
) -> ErasureDecision<I, B, K, W, O> {
    let recoverability = match recoverability {
        None => return ErasureDecision::Rejected(MissingInput::RecoverabilityUnknown),
        Some(recoverability) => recoverability,
    };
    let ErasureRequest {
        target,
        target_basis,
        removed_observations,
        preserved_observations,
    } = request;
    if matches!(recoverability, Recoverability::Irrecoverable) && removed_observations.is_empty() {
        return ErasureDecision::Rejected(MissingInput::RemovedObservationsUndeclared);
    }

    let mut reasons = Vec::new();
    if let Some(basis) = target_basis {
        if live.active_bases.contains(&basis) {
            reasons.push(RetentionReason::ActiveBasis(basis));
        }
    }
    if live.branch_roots.contains(&target) {
        reasons.push(RetentionReason::BranchRoot(target.clone()));
    }
    if live.future_uses.contains(&target) {
        reasons.push(RetentionReason::FutureUse(target.clone()));
    }
    if live.outstanding_effects.contains(&target) {
        reasons.push(RetentionReason::OutstandingEffect(target.clone()));
    }
    if live.outstanding_signals.contains(&target) {
        reasons.push(RetentionReason::OutstandingSignal(target.clone()));
    }
    if matches!(recoverability, Recoverability::ExternalReobservation) {
        reasons.push(RetentionReason::ExternalReobservation);
    }
    if matches!(recoverability, Recoverability::Irrecoverable) {
        for observation in &removed_observations {
            if preserved_observations.contains(observation) {
                reasons.push(RetentionReason::ObservationNotPreserved(
                    observation.clone(),
                ));
            }
        }
    }

    if reasons.is_empty() {
        ErasureDecision::Dematerialize(DematerializeWitness {
            target,
            recoverability,
            removed_observations,
        })
    } else {
        ErasureDecision::Retain(reasons)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    type Id = &'static str;
    type Basis = &'static str;
    type Obs = &'static str;
    type Decision = ErasureDecision<Id, Basis, Opaque, Opaque, Obs>;

    struct Opaque(&'static str);

    fn request(
        target: Id,
        target_basis: Option<Basis>,
        removed: Vec<Obs>,
        preserved: Vec<Obs>,
    ) -> ErasureRequest<Id, Basis, Obs> {
        ErasureRequest {
            target,
            target_basis,
            removed_observations: removed,
            preserved_observations: preserved,
        }
    }

    fn empty_live() -> LiveSet<Id, Basis> {
        LiveSet {
            active_bases: vec![],
            branch_roots: vec![],
            future_uses: vec![],
            outstanding_effects: vec![],
            outstanding_signals: vec![],
        }
    }

    fn live_all(target: Id, basis: Basis) -> LiveSet<Id, Basis> {
        LiveSet {
            active_bases: vec![basis],
            branch_roots: vec![target],
            future_uses: vec![target],
            outstanding_effects: vec![target],
            outstanding_signals: vec![target],
        }
    }

    fn source() -> Option<Recoverability<Opaque, Opaque>> {
        Some(Recoverability::Source(Opaque("source-ref")))
    }

    fn irrecoverable() -> Option<Recoverability<Opaque, Opaque>> {
        Some(Recoverability::Irrecoverable)
    }

    fn retained(decision: Decision) -> Vec<RetentionReason<Id, Basis, Obs>> {
        match decision {
            ErasureDecision::Retain(reasons) => reasons,
            _ => panic!("Retain を期待した"),
        }
    }

    fn rejected(decision: Decision) -> MissingInput {
        match decision {
            ErasureDecision::Rejected(missing) => missing,
            _ => panic!("Rejected を期待した"),
        }
    }

    fn dematerialized(decision: Decision) -> DematerializeWitness<Id, Opaque, Opaque, Obs> {
        match decision {
            ErasureDecision::Dematerialize(witness) => witness,
            _ => panic!("Dematerialize を期待した"),
        }
    }

    fn source_key(witness: &DematerializeWitness<Id, Opaque, Opaque, Obs>) -> &'static str {
        match &witness.recoverability {
            Recoverability::Source(key) => key.0,
            _ => panic!("Source を期待した"),
        }
    }

    #[test]
    fn missing_recoverability_is_rejected_before_any_live_reason() {
        let decision = judge_erasure(
            request("t", Some("b"), vec![], vec![]),
            &live_all("t", "b"),
            None::<Recoverability<Opaque, Opaque>>,
        );
        assert_eq!(rejected(decision), MissingInput::RecoverabilityUnknown);
    }

    #[test]
    fn undeclared_irrecoverable_is_rejected_before_any_live_reason() {
        let decision = judge_erasure(
            request("t", Some("b"), vec![], vec!["a"]),
            &live_all("t", "b"),
            irrecoverable(),
        );
        assert_eq!(
            rejected(decision),
            MissingInput::RemovedObservationsUndeclared
        );
    }

    #[test]
    fn active_basis_alone_is_retained() {
        let live = LiveSet {
            active_bases: vec!["b"],
            ..empty_live()
        };
        let decision = judge_erasure(request("t", Some("b"), vec![], vec![]), &live, source());
        assert_eq!(retained(decision), vec![RetentionReason::ActiveBasis("b")]);
    }

    #[test]
    fn branch_root_alone_is_retained() {
        let live = LiveSet {
            branch_roots: vec!["t"],
            ..empty_live()
        };
        let decision = judge_erasure(request("t", None, vec![], vec![]), &live, source());
        assert_eq!(retained(decision), vec![RetentionReason::BranchRoot("t")]);
    }

    #[test]
    fn future_use_alone_is_retained() {
        let live = LiveSet {
            future_uses: vec!["t"],
            ..empty_live()
        };
        let decision = judge_erasure(request("t", None, vec![], vec![]), &live, source());
        assert_eq!(retained(decision), vec![RetentionReason::FutureUse("t")]);
    }

    #[test]
    fn outstanding_effect_alone_is_retained() {
        let live = LiveSet {
            outstanding_effects: vec!["t"],
            ..empty_live()
        };
        let decision = judge_erasure(request("t", None, vec![], vec![]), &live, source());
        assert_eq!(
            retained(decision),
            vec![RetentionReason::OutstandingEffect("t")]
        );
    }

    #[test]
    fn outstanding_signal_alone_is_retained() {
        let live = LiveSet {
            outstanding_signals: vec!["t"],
            ..empty_live()
        };
        let decision = judge_erasure(request("t", None, vec![], vec![]), &live, source());
        assert_eq!(
            retained(decision),
            vec![RetentionReason::OutstandingSignal("t")]
        );
    }

    #[test]
    fn external_reobservation_alone_is_retained() {
        let decision = judge_erasure(
            request("t", None, vec![], vec![]),
            &empty_live(),
            Some(Recoverability::ExternalReobservation),
        );
        assert_eq!(
            retained(decision),
            vec![RetentionReason::ExternalReobservation]
        );
    }

    #[test]
    fn observation_not_preserved_alone_is_retained() {
        let decision = judge_erasure(
            request("t", None, vec!["a"], vec!["a"]),
            &empty_live(),
            irrecoverable(),
        );
        assert_eq!(
            retained(decision),
            vec![RetentionReason::ObservationNotPreserved("a")]
        );
    }

    #[test]
    fn target_outside_every_live_list_is_dematerialized() {
        let live = LiveSet {
            active_bases: vec!["x"],
            branch_roots: vec!["x"],
            future_uses: vec!["x"],
            outstanding_effects: vec!["x"],
            outstanding_signals: vec!["x"],
        };
        let decision = judge_erasure(request("t", Some("b"), vec![], vec![]), &live, source());
        let witness = dematerialized(decision);
        assert_eq!(witness.target, "t");
        assert_eq!(source_key(&witness), "source-ref");
        assert!(witness.removed_observations.is_empty());
    }

    #[test]
    fn source_recoverability_yields_no_external_reason() {
        let decision = judge_erasure(request("t", None, vec![], vec![]), &empty_live(), source());
        assert!(matches!(decision, ErasureDecision::Dematerialize(_)));
    }

    #[test]
    fn all_five_live_reasons_are_retained_in_condition_order() {
        let decision = judge_erasure(
            request("t", Some("b"), vec![], vec![]),
            &live_all("t", "b"),
            source(),
        );
        assert_eq!(
            retained(decision),
            vec![
                RetentionReason::ActiveBasis("b"),
                RetentionReason::BranchRoot("t"),
                RetentionReason::FutureUse("t"),
                RetentionReason::OutstandingEffect("t"),
                RetentionReason::OutstandingSignal("t"),
            ]
        );
    }

    #[test]
    fn external_reobservation_follows_all_five_live_reasons() {
        let decision = judge_erasure(
            request("t", Some("b"), vec![], vec![]),
            &live_all("t", "b"),
            Some(Recoverability::ExternalReobservation),
        );
        assert_eq!(
            retained(decision),
            vec![
                RetentionReason::ActiveBasis("b"),
                RetentionReason::BranchRoot("t"),
                RetentionReason::FutureUse("t"),
                RetentionReason::OutstandingEffect("t"),
                RetentionReason::OutstandingSignal("t"),
                RetentionReason::ExternalReobservation,
            ]
        );
    }

    #[test]
    fn repeated_observation_reasons_follow_all_five_live_reasons_in_removal_order() {
        let decision = judge_erasure(
            request("t", Some("b"), vec!["a", "b", "a"], vec!["a", "b"]),
            &live_all("t", "b"),
            irrecoverable(),
        );
        assert_eq!(
            retained(decision),
            vec![
                RetentionReason::ActiveBasis("b"),
                RetentionReason::BranchRoot("t"),
                RetentionReason::FutureUse("t"),
                RetentionReason::OutstandingEffect("t"),
                RetentionReason::OutstandingSignal("t"),
                RetentionReason::ObservationNotPreserved("a"),
                RetentionReason::ObservationNotPreserved("b"),
                RetentionReason::ObservationNotPreserved("a"),
            ]
        );
    }

    #[test]
    fn live_duplicates_and_permutations_keep_one_reason_per_kind() {
        let live = LiveSet {
            active_bases: vec!["x", "b", "b"],
            branch_roots: vec!["x", "t", "t"],
            future_uses: vec!["t", "x", "t"],
            outstanding_effects: vec!["t", "t"],
            outstanding_signals: vec!["x", "t"],
        };
        let decision = judge_erasure(request("t", Some("b"), vec![], vec![]), &live, source());
        assert_eq!(
            retained(decision),
            vec![
                RetentionReason::ActiveBasis("b"),
                RetentionReason::BranchRoot("t"),
                RetentionReason::FutureUse("t"),
                RetentionReason::OutstandingEffect("t"),
                RetentionReason::OutstandingSignal("t"),
            ]
        );
    }

    #[test]
    fn removed_observations_outside_preserved_set_stay_in_witness() {
        let decision = judge_erasure(
            request("t", None, vec!["c", "d"], vec!["a"]),
            &empty_live(),
            irrecoverable(),
        );
        let witness = dematerialized(decision);
        assert_eq!(witness.target, "t");
        assert_eq!(witness.removed_observations, vec!["c", "d"]);
        assert!(matches!(
            witness.recoverability,
            Recoverability::Irrecoverable
        ));
    }

    #[test]
    fn only_preserved_removed_observations_are_retained_in_removal_order() {
        let decision = judge_erasure(
            request("t", None, vec!["a", "c", "a"], vec!["a"]),
            &empty_live(),
            irrecoverable(),
        );
        assert_eq!(
            retained(decision),
            vec![
                RetentionReason::ObservationNotPreserved("a"),
                RetentionReason::ObservationNotPreserved("a"),
            ]
        );
    }

    #[test]
    fn source_with_preserved_removed_observation_is_dematerialized() {
        let decision = judge_erasure(
            request("t", None, vec!["a"], vec!["a"]),
            &empty_live(),
            source(),
        );
        let witness = dematerialized(decision);
        assert_eq!(witness.removed_observations, vec!["a"]);
        assert_eq!(source_key(&witness), "source-ref");
    }

    #[test]
    fn source_witness_keeps_target_and_removed_order() {
        let decision = judge_erasure(
            request("t", None, vec!["o2", "o1", "o2"], vec![]),
            &empty_live(),
            source(),
        );
        let witness = dematerialized(decision);
        assert_eq!(witness.target, "t");
        assert_eq!(source_key(&witness), "source-ref");
        assert_eq!(witness.removed_observations, vec!["o2", "o1", "o2"]);
    }

    #[test]
    fn checkpoint_witness_keeps_checkpoint_and_witness_values() {
        let decision = judge_erasure(
            request("t", None, vec!["o1"], vec![]),
            &empty_live(),
            Some(Recoverability::Checkpoint {
                checkpoint: Opaque("checkpoint-ref"),
                witness: Opaque("checkpoint-proof"),
            }),
        );
        let witness = dematerialized(decision);
        assert_eq!(witness.target, "t");
        assert_eq!(witness.removed_observations, vec!["o1"]);
        match witness.recoverability {
            Recoverability::Checkpoint {
                checkpoint,
                witness,
            } => {
                assert_eq!(checkpoint.0, "checkpoint-ref");
                assert_eq!(witness.0, "checkpoint-proof");
            }
            _ => panic!("Checkpoint を期待した"),
        }
    }

    #[test]
    fn replay_witness_keeps_derivation_value() {
        let decision = judge_erasure(
            request("t", None, vec![], vec![]),
            &empty_live(),
            Some(Recoverability::Replay {
                derivation: Opaque("derivation-proof"),
            }),
        );
        let witness = dematerialized(decision);
        assert_eq!(witness.target, "t");
        match witness.recoverability {
            Recoverability::Replay { derivation } => {
                assert_eq!(derivation.0, "derivation-proof");
            }
            _ => panic!("Replay を期待した"),
        }
    }

    #[test]
    fn irrecoverable_witness_keeps_removed_observations_outside_preserved_set_in_order() {
        let decision = judge_erasure(
            request("t", None, vec!["c", "d", "c"], vec!["a"]),
            &empty_live(),
            irrecoverable(),
        );
        let witness = dematerialized(decision);
        assert_eq!(witness.target, "t");
        assert!(matches!(
            witness.recoverability,
            Recoverability::Irrecoverable
        ));
        assert_eq!(witness.removed_observations, vec!["c", "d", "c"]);
    }

    #[test]
    fn opaque_keys_and_witnesses_are_judged_without_clone_or_eq() {
        let decision = judge_erasure(
            request("t", Some("b"), vec![], vec![]),
            &live_all("x", "y"),
            Some(Recoverability::Checkpoint {
                checkpoint: Opaque("k"),
                witness: Opaque("w"),
            }),
        );
        assert!(matches!(decision, ErasureDecision::Dematerialize(_)));
    }
}
