namespace NecoQuotient

/-- 保持の判定に用いる live の宣言: 有効な basis、branch root、将来の利用、未完了の effect と signal -/
structure LiveSet (I B : Type) where
  activeBases : List B
  branchRoots : List I
  futureUses : List I
  outstandingEffects : List I
  outstandingSignals : List I

/-- 再構成の手段: 元の参照、checkpoint と証拠、導出の証拠、外部の再観測、復元不能 -/
inductive Recoverability (K W : Type) where
  | source (k : K)
  | checkpoint (checkpoint : K) (witness : W)
  | replay (derivation : W)
  | externalReobservation
  | irrecoverable

/-- 消去判定の入力: 対象、対象の basis、復元から除く観測、保存する観測 -/
structure ErasureRequest (I B O : Type) where
  target : I
  targetBasis : Option B
  removedObservations : List O
  preservedObservations : List O

/-- 保持の理由 -/
inductive RetentionReason (I B O : Type) where
  | activeBasis (basis : B)
  | branchRoot (target : I)
  | futureUse (target : I)
  | outstandingEffect (target : I)
  | outstandingSignal (target : I)
  | externalReobservation
  | observationNotPreserved (observation : O)

/-- 入力の不足 -/
inductive MissingInput where
  | removedObservationsUndeclared
  | recoverabilityUnknown

/-- 実体化解除の証拠: 対象、再構成の手段、除く観測の宣言 -/
structure DematerializeWitness (I K W O : Type) where
  target : I
  recoverability : Recoverability K W
  removedObservations : List O

/-- 消去の判定結果: 実体化解除、保持の理由の列、入力の不足 -/
inductive ErasureDecision (I B K W O : Type) where
  | dematerialize (witness : DematerializeWitness I K W O)
  | retain (reasons : List (RetentionReason I B O))
  | rejected (missing : MissingInput)

/-- 入力の充足: 再構成の手段が宣言され、復元不能の場合は除く観測が宣言されている -/
def InputsComplete {I B K W O : Type} (req : ErasureRequest I B O) (rec : Option (Recoverability K W)) : Prop :=
  (∃ r, rec = some r) ∧ (rec = some .irrecoverable → req.removedObservations ≠ [])

/-- 保持の理由の条件: 各理由が、対象と宣言された入力の関係として成り立つこと -/
def ReasonHolds {I B K W O : Type} (req : ErasureRequest I B O) (live : LiveSet I B) (rec : Option (Recoverability K W)) : RetentionReason I B O → Prop
  | .activeBasis basis => req.targetBasis = some basis ∧ basis ∈ live.activeBases
  | .branchRoot target => target = req.target ∧ req.target ∈ live.branchRoots
  | .futureUse target => target = req.target ∧ req.target ∈ live.futureUses
  | .outstandingEffect target => target = req.target ∧ req.target ∈ live.outstandingEffects
  | .outstandingSignal target => target = req.target ∧ req.target ∈ live.outstandingSignals
  | .externalReobservation => rec = some .externalReobservation
  | .observationNotPreserved o => rec = some .irrecoverable ∧ o ∈ req.removedObservations ∧ o ∈ req.preservedObservations

/-- 保持の理由の列: live の五条件の順、外部の再観測、復元不能な観測の各出現の順 -/
def retentionReasons {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O] (req : ErasureRequest I B O) (live : LiveSet I B) (r : Recoverability K W) : List (RetentionReason I B O) :=
  (match req.targetBasis with
    | some basis => if basis ∈ live.activeBases then [.activeBasis basis] else []
    | none => [])
  ++ (if req.target ∈ live.branchRoots then [.branchRoot req.target] else [])
  ++ (if req.target ∈ live.futureUses then [.futureUse req.target] else [])
  ++ (if req.target ∈ live.outstandingEffects then [.outstandingEffect req.target] else [])
  ++ (if req.target ∈ live.outstandingSignals then [.outstandingSignal req.target] else [])
  ++ (match r with
    | .externalReobservation => [.externalReobservation]
    | .irrecoverable =>
      (req.removedObservations.filter (fun o => decide (o ∈ req.preservedObservations))).map
        (fun o => RetentionReason.observationNotPreserved o)
    | _ => [])

/-- 再構成の手段が宣言された入力について、保持の理由の列から判定する -/
def decideWith {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O] (req : ErasureRequest I B O) (live : LiveSet I B) (r : Recoverability K W) : ErasureDecision I B K W O :=
  match retentionReasons req live r with
  | [] => .dematerialize { target := req.target, recoverability := r, removedObservations := req.removedObservations }
  | reason :: reasons => .retain (reason :: reasons)

/-- 消去の判定: 入力の不足を先に返し、入力が揃う時は保持の理由の列か実体化解除を返す -/
def judgeErasure {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O] (req : ErasureRequest I B O) (live : LiveSet I B) (rec : Option (Recoverability K W)) : ErasureDecision I B K W O :=
  match rec, req.removedObservations with
  | none, _ => .rejected .recoverabilityUnknown
  | some .irrecoverable, [] => .rejected .removedObservationsUndeclared
  | some r, _ => decideWith req live r

/-- 保持の理由の列への所属は、理由の条件が成り立つことと同値 -/
theorem retentionReasons_mem_iff {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (r : Recoverability K W) (reason : RetentionReason I B O) :
    reason ∈ retentionReasons req live r ↔ ReasonHolds req live (some r) reason := by
  unfold retentionReasons
  cases reason <;> cases r <;> cases hb : req.targetBasis <;>
    simp [ReasonHolds, List.mem_append, List.mem_map, List.mem_filter, hb, eq_comm, and_comm] <;>
    first
    | rfl
    | (intro h; subst h; rfl)

/-- 保持の理由の列が空であることは、全ての理由の条件が成り立たないことと同値 -/
theorem retentionReasons_nil_iff {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (r : Recoverability K W) :
    retentionReasons req live r = [] ↔ ∀ reason, ¬ ReasonHolds req live (some r) reason := by
  constructor
  · intro h reason hr
    have hm := (retentionReasons_mem_iff req live r reason).2 hr
    rw [h] at hm
    cases hm
  · intro h
    cases hl : retentionReasons req live r with
    | nil => rfl
    | cons x xs =>
      exfalso
      have hx : x ∈ retentionReasons req live r := by
        rw [hl]; simp
      exact h x ((retentionReasons_mem_iff req live r x).1 hx)

/-- 入力が揃った判定が実体化解除を返すことは、全ての理由の条件が成り立たないことと同値 -/
theorem decideWith_dematerialize_iff {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (r : Recoverability K W) :
    (∃ w, decideWith req live r = .dematerialize w) ↔ ∀ reason, ¬ ReasonHolds req live (some r) reason := by
  rw [← retentionReasons_nil_iff]
  unfold decideWith
  split
  · rename_i hl
    simp [hl]
  · rename_i x xs hl
    simp [hl]

/-- 入力が揃った判定の保持の列への所属は、保持の理由の列への所属と同値 -/
theorem decideWith_retain_iff {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (r : Recoverability K W) (reason : RetentionReason I B O) :
    (∃ rs, decideWith req live r = .retain rs ∧ reason ∈ rs) ↔ reason ∈ retentionReasons req live r := by
  unfold decideWith
  split
  · rename_i hl
    rw [hl]
    constructor
    · rintro ⟨rs, h, _⟩
      cases h
    · intro h
      simp at h
  · rename_i x xs hl
    rw [hl]
    constructor
    · rintro ⟨rs, h, hm⟩
      cases h
      exact hm
    · intro hm
      exact ⟨x :: xs, rfl, hm⟩

/-- 再構成の手段が宣言され、復元不能の場合は除く観測も宣言された時、判定は入力が揃った判定と一致する -/
theorem judgeErasure_some_complete {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (r : Recoverability K W)
    (h : InputsComplete req (some r)) :
    judgeErasure req live (some r) = decideWith req live r := by
  cases r with
  | irrecoverable =>
    have hne := h.2 rfl
    cases hr : req.removedObservations with
    | nil => exact absurd hr hne
    | cons x xs => simp [judgeErasure, hr]
  | source k => simp [judgeErasure]
  | checkpoint c w => simp [judgeErasure]
  | replay d => simp [judgeErasure]
  | externalReobservation => simp [judgeErasure]

/-- 再構成の手段が未宣言、または復元不能で除く観測が未宣言の時、判定は入力の不足を返す -/
theorem judgeErasure_some_incomplete {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (r : Recoverability K W)
    (h : ¬ InputsComplete req (some r)) :
    ∃ m, judgeErasure req live (some r) = .rejected m := by
  cases r with
  | irrecoverable =>
    cases hr : req.removedObservations with
    | nil => exact ⟨.removedObservationsUndeclared, by simp [judgeErasure, hr]⟩
    | cons x xs => exact absurd ⟨⟨_, rfl⟩, fun _ => by simp [hr]⟩ h
  | source k => exact absurd ⟨⟨_, rfl⟩, fun h' => by cases h'⟩ h
  | checkpoint c w => exact absurd ⟨⟨_, rfl⟩, fun h' => by cases h'⟩ h
  | replay d => exact absurd ⟨⟨_, rfl⟩, fun h' => by cases h'⟩ h
  | externalReobservation => exact absurd ⟨⟨_, rfl⟩, fun h' => by cases h'⟩ h

/-- 実体化解除の証拠は、判定対象と復元から除く観測を保持する -/
theorem decideWith_witness_eq {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (r : Recoverability K W)
    (w : DematerializeWitness I K W O) (h : decideWith req live r = .dematerialize w) :
    w.removedObservations = req.removedObservations ∧ w.target = req.target := by
  unfold decideWith at h
  split at h
  · cases h
    exact ⟨rfl, rfl⟩
  · cases h

/-- 実体化解除は、入力が揃い、全ての保持の理由の条件が成り立たない時と同値 -/
theorem judgeErasure_dematerialize_iff {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (rec : Option (Recoverability K W)) :
    (∃ w, judgeErasure req live rec = .dematerialize w) ↔
      (InputsComplete req rec ∧ ∀ reason, ¬ ReasonHolds req live rec reason) := by
  cases rec with
  | none => simp [judgeErasure, InputsComplete]
  | some r =>
    by_cases h : InputsComplete req (some r)
    · rw [judgeErasure_some_complete req live r h, decideWith_dematerialize_iff]
      exact ⟨fun hall => ⟨h, hall⟩, fun ⟨_, hall⟩ => hall⟩
    · obtain ⟨m, hm⟩ := judgeErasure_some_incomplete req live r h
      rw [hm]
      exact ⟨fun ⟨_, hw⟩ => (by simp at hw), fun hh => absurd hh.1 h⟩

/-- 不足の判定は、再構成の手段の未宣言と、復元不能な区別の除く観測の未宣言の二つと同値 -/
theorem judgeErasure_rejected_iff {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (rec : Option (Recoverability K W)) (m : MissingInput) :
    judgeErasure req live rec = .rejected m ↔
      (m = .recoverabilityUnknown ∧ rec = none) ∨
      (m = .removedObservationsUndeclared ∧ rec = some .irrecoverable ∧ req.removedObservations = []) := by
  cases rec with
  | none => cases m <;> simp [judgeErasure]
  | some r =>
    by_cases h : InputsComplete req (some r)
    · rw [judgeErasure_some_complete req live r h]
      constructor
      · intro hd
        unfold decideWith at hd
        split at hd <;> simp at hd
      · rintro (⟨_, hn⟩ | ⟨_, hk, hr⟩)
        · simp at hn
        · exact absurd hr (h.2 hk)
    · cases r with
      | irrecoverable =>
        cases hr : req.removedObservations with
        | nil => cases m <;> simp [judgeErasure, hr]
        | cons x xs => exact absurd ⟨⟨_, rfl⟩, fun _ => by simp [hr]⟩ h
      | source k => exact absurd ⟨⟨_, rfl⟩, fun h' => by cases h'⟩ h
      | checkpoint c w => exact absurd ⟨⟨_, rfl⟩, fun h' => by cases h'⟩ h
      | replay d => exact absurd ⟨⟨_, rfl⟩, fun h' => by cases h'⟩ h
      | externalReobservation => exact absurd ⟨⟨_, rfl⟩, fun h' => by cases h'⟩ h

/-- 保持の理由が結果の列に含まれることは、入力が揃う時の理由の条件と同値 -/
theorem judgeErasure_reason_iff {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (rec : Option (Recoverability K W))
    (h : InputsComplete req rec) (reason : RetentionReason I B O) :
    (∃ rs, judgeErasure req live rec = .retain rs ∧ reason ∈ rs) ↔ ReasonHolds req live rec reason := by
  have hc := h
  obtain ⟨⟨r, rfl⟩, _⟩ := h
  rw [judgeErasure_some_complete req live r hc, decideWith_retain_iff, retentionReasons_mem_iff]

/-- 復元不能な区別で実体化解除した時、除く観測は全て保存する観測の外にある -/
theorem judgeErasure_irrecoverable_scope {I B K W O : Type} [DecidableEq I] [DecidableEq B] [DecidableEq O]
    (req : ErasureRequest I B O) (live : LiveSet I B) (w : DematerializeWitness I K W O)
    (h : judgeErasure req live (some .irrecoverable) = .dematerialize w) :
    ∀ o, o ∈ w.removedObservations → o ∉ req.preservedObservations := by
  have hc : InputsComplete req (some (Recoverability.irrecoverable : Recoverability K W)) :=
    ((judgeErasure_dematerialize_iff req live (some .irrecoverable)).1 ⟨w, h⟩).1
  have hall := ((judgeErasure_dematerialize_iff req live (some .irrecoverable)).1 ⟨w, h⟩).2
  have hd := h
  rw [judgeErasure_some_complete req live _ hc] at hd
  obtain ⟨hw, _⟩ := decideWith_witness_eq req live _ w hd
  intro o ho hdem
  exact hall (.observationNotPreserved o) ⟨rfl, hw ▸ ho, hdem⟩

end NecoQuotient
