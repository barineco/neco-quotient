namespace NecoQuotient

universe u

/-- 符号 -/
inductive Sign where
  | pos
  | neg
  | zero
  deriving DecidableEq, Repr

/-- 判定結果 -/
inductive Judgment where
  | determined (sign : Sign)
  | undetermined
  deriving DecidableEq, Repr

/-- 線形順序の最小の公理 -/
class Linear (α : Type u) where
  le : α → α → Prop
  decLe : DecidableRel le
  le_refl : ∀ a, le a a
  le_trans : ∀ a b c, le a b → le b c → le a c
  le_antisymm : ∀ a b, le a b → le b a → a = b
  total : ∀ a b, le a b ∨ le b a
  decEq : DecidableEq α

variable {α : Type u}

/-- 非厳密の順序の決定可能性 -/
instance instDecLe [Linear α] (a b : α) : Decidable (Linear.le a b) := Linear.decLe a b

/-- 等号の決定可能性 -/
instance instDecEqLinear [Linear α] : DecidableEq α := Linear.decEq

/-- 狭義の順序 -/
def lt [Linear α] (a b : α) : Prop := Linear.le a b ∧ ¬ Linear.le b a

/-- 狭義の順序の展開 -/
theorem lt_iff [Linear α] {a b : α} : lt a b ↔ (Linear.le a b ∧ ¬ Linear.le b a) :=
  Iff.rfl

/-- 狭義の順序の決定可能性 -/
instance decLt [Linear α] (a b : α) : Decidable (lt a b) :=
  inferInstanceAs (Decidable (Linear.le a b ∧ ¬ Linear.le b a))

/-- 狭義の順序と非厳密の順序の推移 -/
theorem lt_of_lt_of_le [Linear α] {a b c : α} (h1 : lt a b) (h2 : Linear.le b c) : lt a c :=
  lt_iff.mpr ⟨Linear.le_trans _ _ _ (lt_iff.mp h1).1 h2, fun hca => (lt_iff.mp h1).2 (Linear.le_trans _ _ _ h2 hca)⟩

/-- 非厳密の順序と狭義の順序の推移 -/
theorem lt_of_le_of_lt [Linear α] {a b c : α} (h1 : Linear.le a b) (h2 : lt b c) : lt a c :=
  lt_iff.mpr ⟨Linear.le_trans _ _ _ h1 (lt_iff.mp h2).1, fun hca => (lt_iff.mp h2).2 (Linear.le_trans _ _ _ hca h1)⟩

/-- 区間 -/
structure Interval (α : Type u) [Linear α] where
  lower : α
  upper : α
  le : Linear.le lower upper

/-- 区間の包含 -/
def Interval.Sub [Linear α] (I' I : Interval α) : Prop :=
  Linear.le I.lower I'.lower ∧ Linear.le I'.upper I.upper

/-- 区間に対する零との比較による判定 -/
def judge [Linear α] (zero : α) (I : Interval α) : Judgment :=
  if lt zero I.lower then .determined .pos
  else if lt I.upper zero then .determined .neg
  else if I.lower = zero ∧ I.upper = zero then .determined .zero
  else .undetermined

/-- 区間の包含に対する判定の単調性 -/
theorem judge_mono [Linear α] {zero : α} {I' I : Interval α} (h : Interval.Sub I' I) : judge zero I ≠ .undetermined → judge zero I' = judge zero I := by
  obtain ⟨hl, hu⟩ := h
  intro hne
  unfold judge at hne ⊢
  by_cases h1 : lt zero I.lower
  · have h1' : lt zero I'.lower := lt_of_lt_of_le h1 hl
    rw [if_pos h1', if_pos h1]
  · by_cases h2 : lt I.upper zero
    · have h2' : lt I'.upper zero := lt_of_le_of_lt hu h2
      have n1 : ¬ lt zero I'.lower := fun h3 => (lt_iff.mp h2').2 (Linear.le_trans _ _ _ (lt_iff.mp h3).1 I'.le)
      rw [if_neg n1, if_pos h2', if_neg h1, if_pos h2]
    · by_cases h3 : I.lower = zero ∧ I.upper = zero
      · have hz1 : I.lower = zero := h3.1
        have hz2 : I.upper = zero := h3.2
        have hl0 : Linear.le zero I'.lower := by
          rw [hz1] at hl
          exact hl
        have hu0 : Linear.le I'.upper zero := by
          rw [hz2] at hu
          exact hu
        have eL : I'.lower = zero := Linear.le_antisymm _ _ (Linear.le_trans _ _ _ I'.le hu0) hl0
        have eU : I'.upper = zero := Linear.le_antisymm _ _ hu0 (Linear.le_trans _ _ _ hl0 I'.le)
        have n1 : ¬ lt zero I'.lower := by
          rw [eL]
          exact fun hh => (lt_iff.mp hh).2 (Linear.le_refl _)
        have n2 : ¬ lt I'.upper zero := by
          rw [eU]
          exact fun hh => (lt_iff.mp hh).2 (Linear.le_refl _)
        rw [if_neg n1, if_neg n2, if_pos (And.intro eL eU), if_neg h1, if_neg h2, if_pos h3]
      · exact (hne (by rw [if_neg h1, if_neg h2, if_neg h3])).elim

/-- 判定が未決定であることは区間が零を含み、かつ零に一点退化しないことと同値 -/
theorem judge_undetermined_iff [Linear α] {zero : α} {I : Interval α} : judge zero I = .undetermined ↔ (Linear.le I.lower zero ∧ Linear.le zero I.upper ∧ ¬ (I.lower = zero ∧ I.upper = zero)) := by
  unfold judge
  constructor
  · intro h
    by_cases h1 : lt zero I.lower
    · rw [if_pos h1] at h
      cases h
    · by_cases h2 : lt I.upper zero
      · rw [if_neg h1, if_pos h2] at h
        cases h
      · by_cases h3 : I.lower = zero ∧ I.upper = zero
        · rw [if_neg h1, if_neg h2, if_pos h3] at h
          cases h
        · refine ⟨?_, ?_, h3⟩
          · by_cases hl : Linear.le I.lower zero
            · exact hl
            · have hz : Linear.le zero I.lower := (Linear.total I.lower zero).resolve_left hl
              exact absurd (lt_iff.mpr ⟨hz, hl⟩) h1
          · by_cases hu : Linear.le zero I.upper
            · exact hu
            · have hz : Linear.le I.upper zero := (Linear.total zero I.upper).resolve_left hu
              exact absurd (lt_iff.mpr ⟨hz, hu⟩) h2
  · rintro ⟨hl, hu, hn⟩
    have n1 : ¬ lt zero I.lower := fun h => (lt_iff.mp h).2 hl
    have n2 : ¬ lt I.upper zero := fun h => (lt_iff.mp h).2 hu
    rw [if_neg n1, if_neg n2, if_neg hn]

/-- 判定が零であることは区間が零の一点に退化することと同値 -/
theorem judge_zero_iff [Linear α] {zero : α} {I : Interval α} : judge zero I = .determined .zero ↔ (I.lower = zero ∧ I.upper = zero) := by
  unfold judge
  constructor
  · intro h
    by_cases h1 : lt zero I.lower
    · rw [if_pos h1] at h
      cases h
    · by_cases h2 : lt I.upper zero
      · rw [if_neg h1, if_pos h2] at h
        cases h
      · by_cases h3 : I.lower = zero ∧ I.upper = zero
        · exact h3
        · rw [if_neg h1, if_neg h2, if_neg h3] at h
          cases h
  · rintro ⟨hl, hu⟩
    have n1 : ¬ lt zero I.lower := by
      rw [hl]
      exact fun hh => (lt_iff.mp hh).2 (Linear.le_refl _)
    have n2 : ¬ lt I.upper zero := by
      rw [hu]
      exact fun hh => (lt_iff.mp hh).2 (Linear.le_refl _)
    rw [if_neg n1, if_neg n2, if_pos (And.intro hl hu)]

/-- 点ごとの包含区間から判定を返す観測 -/
def judgeObs {X : Type u} [Linear α] (zero : α) (enc : X → Interval α) : X → Judgment := fun x => judge zero (enc x)

/-- 精密化 ( 点ごとの包含 ) で確定済みの判定が保たれる -/
theorem judgeObs_mono {X : Type u} [Linear α] {zero : α} {enc enc' : X → Interval α} (h : ∀ x, Interval.Sub (enc' x) (enc x)) (x : X) : judgeObs zero enc x ≠ .undetermined → judgeObs zero enc' x = judgeObs zero enc x :=
  fun hne => judge_mono (h x) hne

/-- 観測 o' が観測 o の精密化であること: o が確定した点で値が一致する -/
def RefinesObs {X : Type u} (o o' : X → Judgment) : Prop := ∀ x, o x ≠ .undetermined → o' x = o x

/-- 点ごとの包含区間の精密化は判定の観測の精密化である -/
theorem judgeObs_refines {X : Type u} [Linear α] {zero : α} {enc enc' : X → Interval α} (h : ∀ x, Interval.Sub (enc' x) (enc x)) : RefinesObs (judgeObs zero enc) (judgeObs zero enc') :=
  fun x hne => judgeObs_mono h x hne

end NecoQuotient
