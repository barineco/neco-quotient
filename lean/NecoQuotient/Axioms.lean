import NecoQuotient.Observation
import NecoQuotient.Congruence
import NecoQuotient.Bisimulation
import NecoQuotient.Judgment
import NecoQuotient.Blocks
import NecoQuotient.Refinement
import NecoQuotient.Certificate
import NecoQuotient.Guards
import NecoQuotient.BisimRule
import NecoQuotient.Resolver
import NecoQuotient.RuleTable
import NecoQuotient.Retention

namespace NecoQuotient

/-- info: 'NecoQuotient.ObsEquiv.refl' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.ObsEquiv.refl
/-- info: 'NecoQuotient.ObsEquiv.symm' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.ObsEquiv.symm
/-- info: 'NecoQuotient.ObsEquiv.trans' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.ObsEquiv.trans
/-- info: 'NecoQuotient.ObsEquiv.mono' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.ObsEquiv.mono
/-- info: 'NecoQuotient.ObsEquiv.distinct_preserved' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.ObsEquiv.distinct_preserved
/-- info: 'NecoQuotient.q_eq_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.q_eq_iff
/-- info: 'NecoQuotient.coarsen_q' depends on axioms: [Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.coarsen_q
/-- info: 'NecoQuotient.respects_pullback' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.respects_pullback
/-- info: 'NecoQuotient.commute' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.commute
/-- info: 'NecoQuotient.Congruent.comp' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.Congruent.comp
/-- info: 'NecoQuotient.Congruent.pullback_sub' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.Congruent.pullback_sub
/-- info: 'NecoQuotient.commute_congruent' depends on axioms: [Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.commute_congruent
/-- info: 'NecoQuotient.Bisimilar.refl' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.Bisimilar.refl
/-- info: 'NecoQuotient.Bisimilar.symm' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.Bisimilar.symm
/-- info: 'NecoQuotient.Bisimilar.trans' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.Bisimilar.trans
/-- info: 'NecoQuotient.Bisim.run_eq' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.Bisim.run_eq
/-- info: 'NecoQuotient.Bisimilar.run_eq' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.Bisimilar.run_eq
/-- info: 'NecoQuotient.lt_iff' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.lt_iff
/-- info: 'NecoQuotient.lt_of_lt_of_le' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.lt_of_lt_of_le
/-- info: 'NecoQuotient.lt_of_le_of_lt' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.lt_of_le_of_lt
/-- info: 'NecoQuotient.judge_mono' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.judge_mono
/-- info: 'NecoQuotient.judge_undetermined_iff' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.judge_undetermined_iff
/-- info: 'NecoQuotient.judge_zero_iff' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.judge_zero_iff
/-- info: 'NecoQuotient.judgeObs_mono' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.judgeObs_mono
/-- info: 'NecoQuotient.classBlock_consistent' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.classBlock_consistent
/-- info: 'NecoQuotient.classBlocks_cover' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.classBlocks_cover
/-- info: 'NecoQuotient.refine_is_refinement' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.refine_is_refinement

/-- info: 'NecoQuotient.commute_map' depends on axioms: [Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.commute_map
/-- info: 'NecoQuotient.pullback_congruentMap' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.pullback_congruentMap
/-- info: 'NecoQuotient.judgeObs_refines' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.judgeObs_refines
/-- info: 'NecoQuotient.RefinesObs.refl' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.RefinesObs.refl
/-- info: 'NecoQuotient.RefinesObs.trans' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.RefinesObs.trans
/-- info: 'NecoQuotient.ObservationFamilyRefines.of_subset' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.ObservationFamilyRefines.of_subset
/-- info: 'NecoQuotient.ObservationFamilyRefines.trans' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.ObservationFamilyRefines.trans
/-- info: 'NecoQuotient.observationFamilyRefines_equiv_mono' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.observationFamilyRefines_equiv_mono
/-- info: 'NecoQuotient.observationFamilyRefines_distinct_preserved' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.observationFamilyRefines_distinct_preserved
/-- info: 'NecoQuotient.observationFamilyRefines_determined_preserved' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.observationFamilyRefines_determined_preserved
/-- info: 'NecoQuotient.Bisimilar.obsEquiv' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.Bisimilar.obsEquiv
/-- info: 'NecoQuotient.RegionQuotient.block_equiv' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.RegionQuotient.block_equiv
/-- info: 'NecoQuotient.RegionQuotient.block_subset_classBlock' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.RegionQuotient.block_subset_classBlock

/-- info: 'NecoQuotient.Bisim₂.run_eq' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.Bisim₂.run_eq
/-- info: 'NecoQuotient.Bisim₂_self_iff' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.Bisim₂_self_iff
/-- info: 'NecoQuotient.KeyBisimRule.bisim' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.KeyBisimRule.bisim
/-- info: 'NecoQuotient.KeyBisimRule.run_eq' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.KeyBisimRule.run_eq
/-- info: 'NecoQuotient.KeyBisimRule.bisimilar' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.KeyBisimRule.bisimilar
/-- info: 'NecoQuotient.KeyBisimRule.run_eq_of_checked' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.KeyBisimRule.run_eq_of_checked
/-- info: 'NecoQuotient.KeyBisimRule.bisimilar_of_checked' does not depend on any axioms -/
#guard_msgs in #print axioms NecoQuotient.KeyBisimRule.bisimilar_of_checked



/-- info: 'NecoQuotient.admit_sound' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admit_sound
/-- info: 'NecoQuotient.admit_ok_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admit_ok_iff
/-- info: 'NecoQuotient.admit_complete' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admit_complete
/-- info: 'NecoQuotient.admit_provenance' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admit_provenance
/-- info: 'NecoQuotient.admitSelected_ok_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admitSelected_ok_iff
/-- info: 'NecoQuotient.admitSelected_error_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admitSelected_error_iff
/-- info: 'NecoQuotient.admitSelected_error_sound' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.admitSelected_error_sound
/-- info: 'NecoQuotient.admitSelected_error_complete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.admitSelected_error_complete
/-- info: 'NecoQuotient.admitSelected_unchecked_decode' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admitSelected_unchecked_decode
/-- info: 'NecoQuotient.admitSelected_unchecked_source' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admitSelected_unchecked_source
/-- info: 'NecoQuotient.statusAt_matched_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.statusAt_matched_iff
/-- info: 'NecoQuotient.statusAt_mismatched_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.statusAt_mismatched_iff
/-- info: 'NecoQuotient.statusAt_coordinate_independent' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.statusAt_coordinate_independent
/-- info: 'NecoQuotient.statusAt_observations_independent' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.statusAt_observations_independent
/-- info: 'NecoQuotient.statusAt_residual_independent' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.statusAt_residual_independent
/-- info: 'NecoQuotient.checksOf_provenance' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.checksOf_provenance
/-- info: 'NecoQuotient.DigestChecks.check_certificateOnly' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.DigestChecks.check_certificateOnly
/-- info: 'NecoQuotient.DigestChecks.check_recomputedOnly' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.DigestChecks.check_recomputedOnly
/-- info: 'NecoQuotient.DigestChecks.check_matched' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.DigestChecks.check_matched
/-- info: 'NecoQuotient.DigestChecks.check_different' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.DigestChecks.check_different
/-- info: 'NecoQuotient.DigestChecks.check_none' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.DigestChecks.check_none
/-- info: 'NecoQuotient.DigestChecks.allMatched_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.DigestChecks.allMatched_iff
/-- info: 'NecoQuotient.admitResolved_decode_first' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admitResolved_decode_first
/-- info: 'NecoQuotient.admitResolved_resolution' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admitResolved_resolution
/-- info: 'NecoQuotient.admitResolved_stale' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.admitResolved_stale
/-- info: 'NecoQuotient.admitResolved_source_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admitResolved_source_eq
/-- info: 'NecoQuotient.admitWithRules_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admitWithRules_eq
/-- info: 'NecoQuotient.admitWithRules_ok_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.admitWithRules_ok_iff
/-- info: 'NecoQuotient.admitWithRules_unregistered' depends on axioms: [propext] -/
#guard_msgs in #print axioms NecoQuotient.admitWithRules_unregistered
/-- info: 'NecoQuotient.StatefulRule.summary_eq_of_checked' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.StatefulRule.summary_eq_of_checked

/-- info: 'NecoQuotient.judgeErasure_dematerialize_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.judgeErasure_dematerialize_iff
/-- info: 'NecoQuotient.judgeErasure_reason_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.judgeErasure_reason_iff
/-- info: 'NecoQuotient.judgeErasure_rejected_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.judgeErasure_rejected_iff
/-- info: 'NecoQuotient.judgeErasure_irrecoverable_scope' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms NecoQuotient.judgeErasure_irrecoverable_scope

end NecoQuotient
