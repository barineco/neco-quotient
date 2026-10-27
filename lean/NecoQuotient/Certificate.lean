namespace NecoQuotient

/-- 残余の意味集合 -/
structure ResidualSet (R : Type) where
  private mk ::
  values : List R

/-- 重複を除く -/
def ResidualSet.deduplicate {R : Type} [DecidableEq R] : List R → List R
  | [] => []
  | value :: rest =>
    if value ∈ rest then ResidualSet.deduplicate rest
    else value :: ResidualSet.deduplicate rest

/-- 通信配列の要素から意味上の残余集合を作る -/
def ResidualSet.ofList {R : Type} [DecidableEq R] (values : List R) : ResidualSet R :=
  ⟨ResidualSet.deduplicate values⟩

/-- 残余集合の要素所属が一致するかを返す -/
def ResidualSet.same {R : Type} [DecidableEq R] (left right : ResidualSet R) : Bool :=
  left.values.all (fun value => decide (value ∈ right.values))
    && right.values.all (fun value => decide (value ∈ left.values))

#guard ResidualSet.same (ResidualSet.ofList ["b", "a", "a"]) (ResidualSet.ofList ["a", "b"]) == true
#guard ResidualSet.same (ResidualSet.ofList ["b", "a"]) (ResidualSet.ofList ["a", "c"]) == false

/-- 射影ダイジェストの比較範囲 -/
inductive DigestScope where
  | withinRuntime (runtime : String)
  | crossLanguage (encoding : String)
  deriving DecidableEq, Repr

/-- 射影ダイジェスト -/
structure ProjectionDigest where
  projection : String
  digest : String
  scope : DigestScope
  deriving DecidableEq, Repr

/-- 入力参照: 識別子とリビジョン -/
structure SourceRef (S Rev : Type) where
  identity : S
  revision : Rev
  deriving DecidableEq

/-- 証明書 -/
structure Certificate (S Rev C Obs R E : Type) where
  ruleRevision : String
  source : SourceRef S Rev
  coordinate : C
  digests : List ProjectionDigest
  residuals : ResidualSet R
  observations : Obs
  evidence : E

/-- 期待値 -/
structure Expected (S Rev C Obs R : Type) where
  ruleRevision : String
  source : SourceRef S Rev
  coordinate : C
  observations : Obs
  residuals : ResidualSet R

/-- 照合の段階 -/
inductive Stage where
  | decode
  | source
  | coordinate
  | observations
  | digest
  | residual
  deriving DecidableEq, Repr

/-- 不一致の記録: 来歴 P と下位の不一致を持つ -/
inductive Mismatch (P : Type) where
  | mk (operation : String) (stage : Stage) (expected actual : String) (provenance : P) (contributing : List (Mismatch P))

/-- 不一致の操作名 -/
def Mismatch.operation {P : Type} : Mismatch P → String
  | .mk operation _ _ _ _ _ => operation

/-- 不一致の段階 -/
def Mismatch.stage {P : Type} : Mismatch P → Stage
  | .mk _ stage _ _ _ _ => stage

/-- 不一致の期待値の表示 -/
def Mismatch.expected {P : Type} : Mismatch P → String
  | .mk _ _ expected _ _ _ => expected

/-- 不一致の実際の値の表示 -/
def Mismatch.actual {P : Type} : Mismatch P → String
  | .mk _ _ _ actual _ _ => actual

/-- 不一致の来歴 -/
def Mismatch.provenance {P : Type} : Mismatch P → P
  | .mk _ _ _ _ provenance _ => provenance

/-- 不一致の下位の失敗 -/
def Mismatch.contributing {P : Type} : Mismatch P → List (Mismatch P)
  | .mk _ _ _ _ _ contributing => contributing

/-- 照合済みの証明書 -/
structure Checked (S Rev C Obs R E : Type) where
  private mk ::
  input : Certificate S Rev C Obs R E
  expected : Expected S Rev C Obs R
  recomputed : List ProjectionDigest
  ruleRevision_eq : input.ruleRevision = expected.ruleRevision
  source_eq : input.source = expected.source
  coordinate_eq : input.coordinate = expected.coordinate
  observations_eq : input.observations = expected.observations
  digests_eq : input.digests = recomputed
  residuals_match : Bool
  residuals_match_eq : residuals_match = true

private def mkMismatch {P : Type} (stage : Stage) (expected actual : String) (provenance : P) : Mismatch P :=
  Mismatch.mk "admit" stage expected actual provenance []

private def sourceText {S Rev : Type} [ToString S] [ToString Rev] (s : SourceRef S Rev) : String :=
  toString s.identity ++ "@" ++ toString s.revision

/-- 証明書を期待値と段階順に照合する -/
def admit {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest) (provenance : P) : Except (Mismatch P) (Checked S Rev C Obs R E) :=
  if h1 : c.ruleRevision = e.ruleRevision then
    if h2 : c.source = e.source then
      if h3 : c.coordinate = e.coordinate then
        if h4 : c.observations = e.observations then
          if h5 : c.digests = recompute c.source c.coordinate c.observations c.evidence then
            if h6 : ResidualSet.same c.residuals e.residuals = true then
              Except.ok (Checked.mk c e (recompute c.source c.coordinate c.observations c.evidence) h1 h2 h3 h4 h5 (ResidualSet.same c.residuals e.residuals) h6)
            else Except.error (mkMismatch .residual (toString e.residuals.values) (toString c.residuals.values) provenance)
          else Except.error (mkMismatch .digest (reprStr (recompute c.source c.coordinate c.observations c.evidence)) (reprStr c.digests) provenance)
        else Except.error (mkMismatch .observations (toString e.observations) (toString c.observations) provenance)
      else Except.error (mkMismatch .coordinate (toString e.coordinate) (toString c.coordinate) provenance)
    else Except.error (mkMismatch .source (sourceText e.source) (sourceText c.source) provenance)
  else Except.error (mkMismatch .decode e.ruleRevision c.ruleRevision provenance)

/-- 受理された照合は元の証明書と期待値と再計算を保つ -/
theorem admit_sound {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} {k : Checked S Rev C Obs R E} (h : admit (P := P) c e recompute prov = Except.ok k) : k.input = c ∧ k.expected = e ∧ k.recomputed = recompute c.source c.coordinate c.observations c.evidence ∧ ResidualSet.same c.residuals e.residuals = true := by
  unfold admit at h
  repeat' split at h
  all_goals (cases h <;> simp_all)

/-- 全ての欄が一致する証明書は受理される -/
theorem admit_complete {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} (h1 : c.ruleRevision = e.ruleRevision) (h2 : c.source = e.source) (h3 : c.coordinate = e.coordinate) (h4 : c.observations = e.observations) (h5 : c.digests = recompute c.source c.coordinate c.observations c.evidence) (h6 : ResidualSet.same c.residuals e.residuals = true) : ∃ k, admit (P := P) c e recompute prov = Except.ok k := by
  unfold admit
  rw [dif_pos h1, dif_pos h2, dif_pos h3, dif_pos h4, dif_pos h5, dif_pos h6]
  exact ⟨_, rfl⟩

/-- 受理と六つの段階の等式の同値 -/
theorem admit_ok_iff {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} : (∃ k, admit (P := P) c e recompute prov = Except.ok k) ↔ (c.ruleRevision = e.ruleRevision ∧ c.source = e.source ∧ c.coordinate = e.coordinate ∧ c.observations = e.observations ∧ c.digests = recompute c.source c.coordinate c.observations c.evidence ∧ ResidualSet.same c.residuals e.residuals = true) := by
  constructor
  · rintro ⟨k, hk⟩
    obtain ⟨hi, he, hr, hs⟩ := admit_sound hk
    rw [← hi] at hr
    rw [← hi, ← he] at hs
    rw [← hi, ← he]
    exact ⟨k.ruleRevision_eq, k.source_eq, k.coordinate_eq, k.observations_eq, k.digests_eq.trans hr, hs⟩
  · rintro ⟨h1, h2, h3, h4, h5, h6⟩
    exact admit_complete h1 h2 h3 h4 h5 h6

/-- リビジョンの不一致は decode の段階で最初に検出される -/
theorem admit_decode_first {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} (h : c.ruleRevision ≠ e.ruleRevision) : ∃ m, admit (P := P) c e recompute prov = Except.error m ∧ m.stage = Stage.decode := by
  refine ⟨mkMismatch Stage.decode e.ruleRevision c.ruleRevision prov, ?_, rfl⟩
  unfold admit
  rw [dif_neg h]

/-- リビジョンが一致し入力参照が不一致なら source の段階で検出される -/
theorem admit_source_first {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} (h1 : c.ruleRevision = e.ruleRevision) (h2 : c.source ≠ e.source) : ∃ m, admit (P := P) c e recompute prov = Except.error m ∧ m.stage = Stage.source := by
  refine ⟨mkMismatch Stage.source (sourceText e.source) (sourceText c.source) prov, ?_, rfl⟩
  unfold admit
  rw [dif_pos h1, dif_neg h2]

/-- リビジョンと入力参照が一致し座標が不一致なら coordinate の段階で検出される -/
theorem admit_coordinate_stage {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} (h1 : c.ruleRevision = e.ruleRevision) (h2 : c.source = e.source) (h3 : c.coordinate ≠ e.coordinate) : ∃ m, admit (P := P) c e recompute prov = Except.error m ∧ m.stage = Stage.coordinate := by
  refine ⟨mkMismatch Stage.coordinate (toString e.coordinate) (toString c.coordinate) prov, ?_, rfl⟩
  unfold admit
  rw [dif_pos h1, dif_pos h2, dif_neg h3]

/-- リビジョンと入力参照と座標が一致し観測が不一致なら observations の段階で検出される -/
theorem admit_observations_stage {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} (h1 : c.ruleRevision = e.ruleRevision) (h2 : c.source = e.source) (h3 : c.coordinate = e.coordinate) (h4 : c.observations ≠ e.observations) : ∃ m, admit (P := P) c e recompute prov = Except.error m ∧ m.stage = Stage.observations := by
  refine ⟨mkMismatch Stage.observations (toString e.observations) (toString c.observations) prov, ?_, rfl⟩
  unfold admit
  rw [dif_pos h1, dif_pos h2, dif_pos h3, dif_neg h4]

/-- リビジョンと入力参照と座標と観測が一致し射影ダイジェストが再計算と不一致なら digest の段階で検出される -/
theorem admit_digest_stage {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} (h1 : c.ruleRevision = e.ruleRevision) (h2 : c.source = e.source) (h3 : c.coordinate = e.coordinate) (h4 : c.observations = e.observations) (h5 : c.digests ≠ recompute c.source c.coordinate c.observations c.evidence) : ∃ m, admit (P := P) c e recompute prov = Except.error m ∧ m.stage = Stage.digest := by
  refine ⟨mkMismatch Stage.digest (reprStr (recompute c.source c.coordinate c.observations c.evidence)) (reprStr c.digests) prov, ?_, rfl⟩
  unfold admit
  rw [dif_pos h1, dif_pos h2, dif_pos h3, dif_pos h4, dif_neg h5]

/-- 最初の五段階が一致し残余だけが異なるなら residual の段階で検出される -/
theorem admit_residual_last {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} (h1 : c.ruleRevision = e.ruleRevision) (h2 : c.source = e.source) (h3 : c.coordinate = e.coordinate) (h4 : c.observations = e.observations) (h5 : c.digests = recompute c.source c.coordinate c.observations c.evidence) (h6 : ResidualSet.same c.residuals e.residuals = false) : ∃ m, admit (P := P) c e recompute prov = Except.error m ∧ m.stage = Stage.residual := by
  refine ⟨mkMismatch Stage.residual (toString e.residuals.values) (toString c.residuals.values) prov, ?_, rfl⟩
  unfold admit
  have hn : ¬ ResidualSet.same c.residuals e.residuals = true := by
    rw [h6]
    decide
  rw [dif_pos h1, dif_pos h2, dif_pos h3, dif_pos h4, dif_pos h5, dif_neg hn]

/-- 不一致の記録は照合に渡された来歴を保つ -/
theorem admit_provenance {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R] {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : SourceRef S Rev → C → Obs → E → List ProjectionDigest} {prov : P} {m : Mismatch P} (h : admit (P := P) c e recompute prov = Except.error m) : m.provenance = prov := by
  unfold admit at h
  repeat' split at h
  all_goals (cases h <;> rfl)

end NecoQuotient
