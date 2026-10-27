import NecoQuotient.Observation

namespace NecoQuotient

universe u

variable {S I O : Type u}

/-- 一手の遷移系 -/
structure Transition (S I O : Type u) where
  step : S → I → S × O

/-- 関係 R が双模倣であること -/
def Bisim (T : Transition S I O) (R : S → S → Prop) : Prop :=
  ∀ s t, R s t → ∀ i, (T.step s i).2 = (T.step t i).2 ∧ R (T.step s i).1 (T.step t i).1

/-- 双模倣な関係で結ばれること -/
def Bisimilar (T : Transition S I O) (s t : S) : Prop := ∃ R, Bisim T R ∧ R s t

/-- 双模倣の反射律 -/
theorem Bisimilar.refl (T : Transition S I O) (s : S) : Bisimilar T s s := by
  unfold Bisimilar
  exact ⟨fun a b => a = b, fun a b (h : a = b) i => by subst h; exact ⟨rfl, rfl⟩, rfl⟩

/-- 双模倣の対称律 -/
theorem Bisimilar.symm {T : Transition S I O} {s t : S} : Bisimilar T s t → Bisimilar T t s := by
  intro h
  unfold Bisimilar at h ⊢
  obtain ⟨R, hB, hR⟩ := h
  exact ⟨fun a b => R b a, fun a b hab i => ⟨(hB b a hab i).1.symm, (hB b a hab i).2⟩, hR⟩

/-- 双模倣の推移律 -/
theorem Bisimilar.trans {T : Transition S I O} {s t w : S} : Bisimilar T s t → Bisimilar T t w → Bisimilar T s w := by
  intro h1 h2
  unfold Bisimilar at h1 h2 ⊢
  obtain ⟨R1, hB1, hR1⟩ := h1
  obtain ⟨R2, hB2, hR2⟩ := h2
  refine ⟨fun a c => ∃ b, R1 a b ∧ R2 b c, ?_, t, hR1, hR2⟩
  unfold Bisim
  intro a c hac i
  obtain ⟨b, hab, hbc⟩ := hac
  exact ⟨(hB1 a b hab i).1.trans (hB2 b c hbc i).1, (T.step b i).1, (hB1 a b hab i).2, (hB2 b c hbc i).2⟩

/-- 入力の列に対する出力の列 -/
def run (T : Transition S I O) : S → List I → List O
  | _, [] => []
  | s, i :: is => (T.step s i).2 :: run T (T.step s i).1 is

/-- 双模倣な二状態は同じ出力の列を返す -/
theorem Bisim.run_eq {T : Transition S I O} {R : S → S → Prop} (h : Bisim T R) {s t : S} (hst : R s t) (is : List I) : run T s is = run T t is := by
  have key : ∀ (l : List I) (a b : S), R a b → run T a l = run T b l := by
    intro l
    induction l with
    | nil => intro a b _; rfl
    | cons i l ih =>
      intro a b hab
      obtain ⟨h1, h2⟩ := h a b hab i
      simp only [run]
      rw [h1, ih _ _ h2]
  exact key is s t hst

/-- 双模倣な二状態は全ての入力列で同じ出力を返す -/
theorem Bisimilar.run_eq {T : Transition S I O} {s t : S} : Bisimilar T s t → ∀ is : List I, run T s is = run T t is := by
  intro h is
  unfold Bisimilar at h
  obtain ⟨R, hB, hR⟩ := h
  exact Bisim.run_eq hB hR is

/-- 入力の列に対する出力の列を返す観測 -/
def traceObs (T : Transition S I O) (is : List I) : S → List O := fun s => run T s is

/-- 双模倣な二状態は、出力の列を観測する任意の入力列の集まりについて観測同値である -/
theorem Bisimilar.obsEquiv {T : Transition S I O} {s t : S} (h : Bisimilar T s t) (iss : List (List I)) : ObsEquiv (iss.map (traceObs T)) s t := by
  intro o ho
  obtain ⟨is, _, rfl⟩ := List.mem_map.mp ho
  exact Bisimilar.run_eq h is

end NecoQuotient
