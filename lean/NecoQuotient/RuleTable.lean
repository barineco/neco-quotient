import NecoQuotient.Certificate
import NecoQuotient.BisimRule

namespace NecoQuotient

/-- リビジョンから一意に決まる再計算の規則 -/
structure Rule (S Rev C Obs E : Type) where
  recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest

/-- リビジョンの名前で規則を引く表 -/
abbrev RuleTable (S Rev C Obs E : Type) := List (String × Rule S Rev C Obs E)

/-- リビジョンの名前で規則を引く -/
def RuleTable.lookup {S Rev C Obs E : Type} (t : RuleTable S Rev C Obs E) (v : String) : Option (Rule S Rev C Obs E) :=
  (t.find? (fun e => e.1 == v)).map (·.2)

/-- 表の規則を引いて照合する。リビジョンの不一致と表に無いリビジョンは decode の段階の不一致で返す -/
def admitWithRules {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (t : RuleTable S Rev C Obs E) (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (prov : P) : Except (Mismatch P) (Checked S Rev C Obs R E) :=
  if c.ruleRevision = e.ruleRevision then
    match t.lookup c.ruleRevision with
    | none => Except.error (Mismatch.mk "admit" Stage.decode "rule in table" c.ruleRevision prov [])
    | some r => admit c e r.recompute prov
  else Except.error (Mismatch.mk "admit" Stage.decode e.ruleRevision c.ruleRevision prov [])

/-- リビジョンが異なる時、表の照合は任意の再計算の関数での照合に等しい -/
theorem admitWithRules_version {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (t : RuleTable S Rev C Obs E) (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (prov : P)
    (recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest) (h : c.ruleRevision ≠ e.ruleRevision) :
    admitWithRules t c e prov = admit c e recompute prov := by
  unfold admitWithRules admit
  rw [if_neg h, dif_neg h]
  rfl

/-- リビジョンが一致し表に規則が無い時、decode の段階の不一致を返す -/
theorem admitWithRules_unknown {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (t : RuleTable S Rev C Obs E) (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (prov : P)
    (h : c.ruleRevision = e.ruleRevision) (hu : t.lookup c.ruleRevision = none) :
    ∃ m, admitWithRules t c e prov = Except.error m ∧ m.stage = Stage.decode := by
  refine ⟨Mismatch.mk "admit" Stage.decode "rule in table" c.ruleRevision prov [], ?_, rfl⟩
  unfold admitWithRules
  rw [if_pos h, hu]

/-- 表に規則がある時、表の照合はその規則の再計算での照合に等しい -/
theorem admitWithRules_eq {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (t : RuleTable S Rev C Obs E) (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (prov : P)
    (r : Rule S Rev C Obs E) (hr : t.lookup c.ruleRevision = some r) :
    admitWithRules t c e prov = admit c e r.recompute prov := by
  by_cases h : c.ruleRevision = e.ruleRevision
  · unfold admitWithRules
    rw [if_pos h, hr]
  · exact admitWithRules_version t c e prov r.recompute h

/-- 状態を持つ系の規則: キーによる双模倣と、キーから代表の状態への写像 -/
structure StatefulRule {S₁ S₂ I O : Type} (T₁ : Transition S₁ I O) (T₂ : Transition S₂ I O) (K : Type) where
  bisim : KeyBisimRule T₁ T₂ K
  summarize : List (List O) → List ProjectionDigest
  reopen : K → S₂
  key_reopen : ∀ k, bisim.key₂ (reopen k) = k

/-- 状態を持つ系の規則を、要求と証拠からの再計算の規則として見る -/
def StatefulRule.asRule {S₁ S₂ I O : Type} {T₁ : Transition S₁ I O} {T₂ : Transition S₂ I O} {K : Type} {Src Rev C : Type}
    (r : StatefulRule T₁ T₂ K) : Rule Src Rev C (List (List I)) K where
  recompute := fun _ _ observations k => r.summarize (observations.map (fun is => run T₂ (r.reopen k) is))

/-- 表の規則が状態を持つ系の規則である照合済みの証明書は、双模倣な二状態の要約を等しくし、再計算の値は元の状態の要約に等しい -/
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
  obtain ⟨hin, _, hrec, _⟩ := admit_sound hA
  have hK : r.bisim.key₁ s = c.evidence := hkey.1.trans (congrArg (fun x => x.evidence) hin)
  have hfun : run T₁ s = run T₂ t := funext (fun is => KeyBisimRule.run_eq_of_checked r.bisim checked hkey is)
  have hfun2 : run T₁ s = run T₂ (r.reopen c.evidence) :=
    funext (fun is => r.bisim.run_eq (hK.trans (r.key_reopen c.evidence).symm) is)
  refine ⟨fun d => ?_, ?_⟩
  · rw [hfun]
  · rw [hrec, hfun2]
    rfl

end NecoQuotient
