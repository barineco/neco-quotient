import NecoQuotient.Certificate
import NecoQuotient.BisimRule

namespace NecoQuotient

structure Rule (S Rev C Obs E : Type) where
  recompute : Recompute S Rev C Obs E

abbrev RuleTable (S Rev C Obs E : Type) := List (String × Rule S Rev C Obs E)

def RuleTable.lookup {S Rev C Obs E : Type} (t : RuleTable S Rev C Obs E) (v : String) : Option (Rule S Rev C Obs E) :=
  (t.find? (fun e => e.1 == v)).map (·.2)

section Rules

variable {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]

def selectWithRules (t : RuleTable S Rev C Obs E) (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (provenance : P) :
    Except (ConditionFailure .decode P) (Selected c e) :=
  if h : c.ruleRevision = e.ruleRevision then
    match t.lookup c.ruleRevision with
    | none => .error (failureOf .decode "rule in table" c.ruleRevision c provenance)
    | some r => .ok ⟨r.recompute, h⟩
  else .error (decodeFailure c e provenance)

def admitWithRules (t : RuleTable S Rev C Obs E) (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (provenance : P) :
    Except (Mismatch P) (Checked S Rev C Obs R E) :=
  admitSelected c e (selectWithRules t c e provenance) provenance

theorem admitWithRules_eq (t : RuleTable S Rev C Obs E) (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (prov : P)
    (r : Rule S Rev C Obs E) (hr : t.lookup c.ruleRevision = some r) :
    admitWithRules t c e prov = admit c e r.recompute prov := by
  unfold admitWithRules admit
  by_cases h : c.ruleRevision = e.ruleRevision
  · have hs : selectWithRules t c e prov = selectDirect c e r.recompute prov := by
      unfold selectWithRules selectDirect
      rw [dif_pos h, dif_pos h, hr]
    rw [hs]
  · have hs : selectWithRules t c e prov = selectDirect c e r.recompute prov := by
      unfold selectWithRules selectDirect
      rw [dif_neg h, dif_neg h]
    rw [hs]

theorem admitWithRules_ok_iff (t : RuleTable S Rev C Obs E) (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (prov : P) :
    (∃ k, admitWithRules t c e prov = .ok k) ↔
      ∃ r, t.lookup c.ruleRevision = some r ∧ c.ruleRevision = e.ruleRevision ∧ c.source = e.source ∧
        c.coordinate = e.coordinate ∧ c.observations = e.observations ∧
        (∀ name : String, c.digests[name]? = (r.recompute c.source c.coordinate c.observations c.evidence)[name]?) ∧
        ResidualSet.same c.residuals e.residuals = true := by
  cases hl : t.lookup c.ruleRevision with
  | none =>
    simp only [reduceCtorEq, false_and, exists_false, iff_false]
    rintro ⟨k, hk⟩
    unfold admitWithRules at hk
    obtain ⟨s, hs, -⟩ := admitSelected_ok_checks hk
    unfold selectWithRules at hs
    split at hs
    · rw [hl] at hs
      cases hs
    · cases hs
  | some r =>
    rw [admitWithRules_eq t c e prov r hl, admit_ok_iff]
    simp

theorem admitWithRules_unregistered (t : RuleTable S Rev C Obs E) (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (prov : P)
    (h : c.ruleRevision = e.ruleRevision) (hu : t.lookup c.ruleRevision = none) :
    ∃ m f, admitWithRules t c e prov = .error m ∧ m.statusAt .decode = .mismatched ∧
      m.statusAt .digest = .uncheckedByDecode f := by
  have hs : selectWithRules t c e prov = .error (failureOf .decode "rule in table" c.ruleRevision c prov) := by
    unfold selectWithRules
    rw [dif_pos h, hu]
  obtain ⟨m, hm, h1, h2⟩ := admitSelected_of_decode_error (c := c) (e := e) (provenance := prov) hs
  exact ⟨m, _, hm, h1, h2⟩

end Rules

structure StatefulRule {S₁ S₂ I O : Type} (T₁ : Transition S₁ I O) (T₂ : Transition S₂ I O) (K : Type) where
  bisim : KeyBisimRule T₁ T₂ K
  summarize : List (List O) → ProjectionDigests
  reopen : K → S₂
  key_reopen : ∀ k, bisim.key₂ (reopen k) = k

def StatefulRule.asRule {S₁ S₂ I O : Type} {T₁ : Transition S₁ I O} {T₂ : Transition S₂ I O} {K : Type} {Src Rev C : Type}
    (r : StatefulRule T₁ T₂ K) : Rule Src Rev C (List (List I)) K where
  recompute := fun _ _ observations k => r.summarize (observations.map (fun is => run T₂ (r.reopen k) is))

theorem StatefulRule.summary_eq_of_checked {S₁ S₂ I O Src Rev C R P : Type} [DecidableEq Src] [DecidableEq Rev] [DecidableEq C] [DecidableEq I] [DecidableEq R] [ToString Src] [ToString Rev] [ToString C] [ToString I] [ToString R]
    {T₁ : Transition S₁ I O} {T₂ : Transition S₂ I O} {K : Type}
    (r : StatefulRule T₁ T₂ K) (table : RuleTable Src Rev C (List (List I)) K)
    (c : Certificate Src Rev C (List (List I)) R K) (expected : Expected Src Rev C (List (List I)) R) (prov : P)
    (checked : Checked Src Rev C (List (List I)) R K)
    (hlook : table.lookup c.ruleRevision = some r.asRule)
    (hadm : admitWithRules table c expected prov = Except.ok checked)
    (s : S₁) (t : S₂) (hkey : r.bisim.keyMatches checked s t) :
    (∀ d : List (List I), r.summarize (d.map (run T₁ s)) = r.summarize (d.map (run T₂ t))) ∧
      checked.recomputed = r.summarize (c.observations.map (run T₁ s)) := by
  have hA := (admitWithRules_eq table c expected prov r.asRule hlook).symm.trans hadm
  obtain ⟨hin, _, hrec⟩ := admit_sound hA
  have hK : r.bisim.key₁ s = c.evidence := hkey.1.trans (congrArg (fun x => x.evidence) hin)
  have hfun : run T₁ s = run T₂ t := funext (fun is => KeyBisimRule.run_eq_of_checked r.bisim checked hkey is)
  have hfun2 : run T₁ s = run T₂ (r.reopen c.evidence) :=
    funext (fun is => r.bisim.run_eq (hK.trans (r.key_reopen c.evidence).symm) is)
  refine ⟨fun d => ?_, ?_⟩
  · rw [hfun]
  · rw [hrec, hfun2]
    rfl

end NecoQuotient
