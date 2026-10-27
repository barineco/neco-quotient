import NecoQuotient.Bisimulation
import NecoQuotient.Certificate

namespace NecoQuotient

universe u v

variable {S S₁ S₂ I O : Type u}

/-- 二つの遷移系の状態を結ぶ関係が双模倣であること -/
def Bisim₂ (T₁ : Transition S₁ I O) (T₂ : Transition S₂ I O) (R : S₁ → S₂ → Prop) : Prop :=
  ∀ s t, R s t → ∀ i, (T₁.step s i).2 = (T₂.step t i).2 ∧ R (T₁.step s i).1 (T₂.step t i).1

/-- 二つの遷移系の双模倣で結ばれた二状態は、全ての入力列で同じ出力の列を返す -/
theorem Bisim₂.run_eq {T₁ : Transition S₁ I O} {T₂ : Transition S₂ I O} {R : S₁ → S₂ → Prop}
    (h : Bisim₂ T₁ T₂ R) {s : S₁} {t : S₂} (hst : R s t) (is : List I) : run T₁ s is = run T₂ t is := by
  have key : ∀ (l : List I) (a : S₁) (b : S₂), R a b → run T₁ a l = run T₂ b l := by
    intro l
    induction l with
    | nil => intro a b _; rfl
    | cons i l ih =>
      intro a b hab
      obtain ⟨h1, h2⟩ := h a b hab i
      simp only [run]
      rw [h1, ih _ _ h2]
  exact key is s t hst

/-- 同じ遷移系の上の二つの遷移系の双模倣は、一つの遷移系の双模倣と一致する -/
theorem Bisim₂_self_iff {T : Transition S I O} {R : S → S → Prop} : Bisim₂ T T R ↔ Bisim T R :=
  Iff.rfl

/-- キーによる二つの遷移系の双模倣を保証する規則の義務 -/
structure KeyBisimRule (T₁ : Transition S₁ I O) (T₂ : Transition S₂ I O) (K : Type v) where
  key₁ : S₁ → K
  key₂ : S₂ → K
  output_eq : ∀ s t i, key₁ s = key₂ t → (T₁.step s i).2 = (T₂.step t i).2
  next_key_eq : ∀ s t i, key₁ s = key₂ t → key₁ (T₁.step s i).1 = key₂ (T₂.step t i).1

/-- 規則のキーの一致は二つの遷移系の双模倣である -/
theorem KeyBisimRule.bisim {T₁ : Transition S₁ I O} {T₂ : Transition S₂ I O} {K : Type v}
    (c : KeyBisimRule T₁ T₂ K) : Bisim₂ T₁ T₂ (fun s t => c.key₁ s = c.key₂ t) := by
  unfold Bisim₂
  intro s t hst i
  exact ⟨c.output_eq s t i hst, c.next_key_eq s t i hst⟩

/-- キーが一致する二状態は、全ての入力列で同じ出力の列を返す -/
theorem KeyBisimRule.run_eq {T₁ : Transition S₁ I O} {T₂ : Transition S₂ I O} {K : Type v}
    (c : KeyBisimRule T₁ T₂ K) {s : S₁} {t : S₂} (h : c.key₁ s = c.key₂ t) (is : List I) :
    run T₁ s is = run T₂ t is :=
  Bisim₂.run_eq c.bisim h is

/-- 同じ遷移系の上の規則でキーが一致する二状態は双模倣である -/
theorem KeyBisimRule.bisimilar {T : Transition S I O} {K : Type v}
    (c : KeyBisimRule T T K) {s t : S} (h : c.key₁ s = c.key₂ t) : Bisimilar T s t := by
  unfold Bisimilar
  exact ⟨fun a b => c.key₁ a = c.key₂ b, c.bisim, h⟩

/-- 照合済みの証明書の証拠のキーが、二つの状態のキーと一致すること -/
def KeyBisimRule.keyMatches {T₁ : Transition S₁ I O} {T₂ : Transition S₂ I O} {Src Rev C Obs Res K : Type} [DecidableEq Res]
    (r : KeyBisimRule T₁ T₂ K) (k : Checked Src Rev C Obs Res K) (s : S₁) (t : S₂) : Prop :=
  r.key₁ s = k.input.evidence ∧ r.key₂ t = k.input.evidence

/-- 照合済みの証明書の証拠のキーと一致する二状態は、全ての入力列で同じ出力の列を返す -/
theorem KeyBisimRule.run_eq_of_checked {T₁ : Transition S₁ I O} {T₂ : Transition S₂ I O} {Src Rev C Obs Res K : Type} [DecidableEq Res]
    (r : KeyBisimRule T₁ T₂ K) (k : Checked Src Rev C Obs Res K) {s : S₁} {t : S₂}
    (h : r.keyMatches k s t) (is : List I) : run T₁ s is = run T₂ t is :=
  r.run_eq (h.1.trans h.2.symm) is

/-- 同じ遷移系の上で、照合済みの証明書の証拠のキーと一致する二状態は双模倣である -/
theorem KeyBisimRule.bisimilar_of_checked {T : Transition S I O} {Src Rev C Obs Res K : Type} [DecidableEq Res]
    (r : KeyBisimRule T T K) (k : Checked Src Rev C Obs Res K) {s t : S}
    (h : r.keyMatches k s t) : Bisimilar T s t :=
  r.bisimilar (h.1.trans h.2.symm)

end NecoQuotient
