import NecoQuotient.Observation
import NecoQuotient.Judgment
import NecoQuotient.Certificate

namespace NecoQuotient

universe u

variable {X : Type u}

/-- 観測の精密化は反射的である -/
theorem RefinesObs.refl {o : X → Judgment} : RefinesObs o o :=
  fun _ _ => rfl

/-- 観測の精密化は推移的である -/
theorem RefinesObs.trans {o o' o'' : X → Judgment} (h1 : RefinesObs o o') (h2 : RefinesObs o' o'') : RefinesObs o o'' :=
  fun x hx => (h2 x (by rw [h1 x hx]; exact hx)).trans (h1 x hx)

/-- 観測関数族 D' が観測関数族 D を精密化すること: D の各観測に、それを精密化する観測が D' の中にある -/
def ObservationFamilyRefines (D D' : ObservationFamily X Judgment) : Prop := ∀ o, o ∈ D → ∃ o', o' ∈ D' ∧ RefinesObs o o'

/-- 観測に対する評価結果 -/
abbrev Evaluation {X : Type u} (D : ObservationFamily X Judgment) (Context : Type u) :=
  Context → (o : X → Judgment) → o ∈ D → Judgment

/-- 評価が参照する source、basis、入力、証明書 -/
structure EvaluationContext (Source Basis InputRef CertRef : Type) (X : Type u) where
  source : Source
  basis : Basis
  inputRef : InputRef
  certificate : CertRef
  input : X

/-- 評価結果が同じ入力の観測を評価した証拠 -/
def EvaluatedAt {Source Basis InputRef CertRef : Type} {X : Type u}
    (D : ObservationFamily X Judgment)
    (context : EvaluationContext Source Basis InputRef CertRef X)
    (result : Evaluation D (EvaluationContext Source Basis InputRef CertRef X)) : Prop :=
  ∀ o ho, result context o ho = o context.input

/-- 精密化の結果の状態 -/
inductive RefinementStatus (Residual Stop : Type)
  | resolved
  | residual (residuals : ResidualSet Residual)
  | stopped (residuals : ResidualSet Residual) (cause : Stop)

/-- 精密化前後の評価と三つの結果状態 -/
structure RefinementResult (Result : Type u) (Residual Stop : Type) where
  evaluation : Result
  status : RefinementStatus Residual Stop

/-- 同じ入力の精密化前後を結び、観測と評価の証拠を保持する結果 -/
structure VerifiedRefinement (Source Basis InputRef CertRef Residual Stop : Type) (X : Type u)
    (D D' : ObservationFamily X Judgment) where
  source : Source
  basis : Basis
  inputRef : InputRef
  certificate : CertRef
  input : X
  before : RefinementResult
    (Evaluation D (EvaluationContext Source Basis InputRef CertRef X)) Residual Stop
  after : RefinementResult
    (Evaluation D' (EvaluationContext Source Basis InputRef CertRef X)) Residual Stop
  observationFamilyRefines : ObservationFamilyRefines D D'
  evaluatedBefore : EvaluatedAt D ⟨source, basis, inputRef, certificate, input⟩ before.evaluation
  evaluatedAfter : EvaluatedAt D' ⟨source, basis, inputRef, certificate, input⟩ after.evaluation

/-- 精密化で前段階の確定済み判定が同じ入力の後段階の評価に残る -/
theorem evaluated_determination_preserved {Source Basis InputRef CertRef : Type}
    {context : EvaluationContext Source Basis InputRef CertRef X}
    {D D' : ObservationFamily X Judgment}
    (h : ObservationFamilyRefines D D')
    {before : Evaluation D (EvaluationContext Source Basis InputRef CertRef X)}
    {after : Evaluation D' (EvaluationContext Source Basis InputRef CertRef X)}
    (beforeAt : EvaluatedAt D context before) (afterAt : EvaluatedAt D' context after)
    {o : X → Judgment} (ho : o ∈ D) (determined : before context o ho ≠ .undetermined) :
    ∃ o', ∃ ho' : o' ∈ D', after context o' ho' = before context o ho := by
  obtain ⟨o', ho', refines⟩ := h o ho
  have hdet : o context.input ≠ .undetermined := by
    rw [← beforeAt o ho]
    exact determined
  refine ⟨o', ho', ?_⟩
  rw [afterAt o' ho', beforeAt o ho]
  exact refines context.input hdet

/-- 観測関数族を広げること ( D ⊆ D' ) は精密化である -/
theorem ObservationFamilyRefines.of_subset {D D' : ObservationFamily X Judgment} (h : ∀ o, o ∈ D → o ∈ D') : ObservationFamilyRefines D D' :=
  fun o ho => ⟨o, h o ho, RefinesObs.refl⟩

/-- 精密化の推移律 -/
theorem ObservationFamilyRefines.trans {D D' D'' : ObservationFamily X Judgment} (h1 : ObservationFamilyRefines D D') (h2 : ObservationFamilyRefines D' D'') : ObservationFamilyRefines D D'' := by
  intro o ho
  obtain ⟨o', ho', hr⟩ := h1 o ho
  obtain ⟨o'', ho'', hr'⟩ := h2 o' ho'
  exact ⟨o'', ho'', RefinesObs.trans hr hr'⟩

/-- 二点の確定の有無が D の全ての観測で一致するとき、精密化の後の同値は前の同値を含意する -/
theorem observationFamilyRefines_equiv_mono {D D' : ObservationFamily X Judgment} (h : ObservationFamilyRefines D D') {x y : X} (hdet : ∀ o, o ∈ D → (o x = .undetermined ↔ o y = .undetermined)) : ObsEquiv D' x y → ObsEquiv D x y := by
  intro hxy o ho
  obtain ⟨o', ho', hr⟩ := h o ho
  by_cases hx : o x = .undetermined
  · have hy : o y = .undetermined := (hdet o ho).mp hx
    rw [hx, hy]
  · have hy : o y ≠ .undetermined := fun hy => hx ((hdet o ho).mpr hy)
    have e1 : o' x = o x := hr x hx
    have e2 : o' y = o y := hr y hy
    rw [← e1, ← e2]
    exact hxy o' ho'

/-- 区別を与える観測が二点で確定していれば、精密化の後も区別が保たれる -/
theorem observationFamilyRefines_distinct_preserved {D D' : ObservationFamily X Judgment} (h : ObservationFamilyRefines D D') {x y : X} {o : X → Judgment} (ho : o ∈ D) (hx : o x ≠ .undetermined) (hy : o y ≠ .undetermined) (hne : o x ≠ o y) : ¬ ObsEquiv D' x y := by
  intro hd
  obtain ⟨o', ho', hr⟩ := h o ho
  have e1 : o' x = o x := hr x hx
  have e2 : o' y = o y := hr y hy
  have hxy : o' x = o' y := hd o' ho'
  rw [e1, e2] at hxy
  exact hne hxy

/-- 確定済みの判定は精密化で保たれる -/
theorem observationFamilyRefines_determined_preserved {D D' : ObservationFamily X Judgment} (h : ObservationFamilyRefines D D') {o : X → Judgment} (ho : o ∈ D) {x : X} (hx : o x ≠ .undetermined) : ∃ o', o' ∈ D' ∧ o' x = o x := by
  obtain ⟨o', ho', hr⟩ := h o ho
  exact ⟨o', ho', hr x hx⟩

private def resolvedObservation : Unit → Judgment := fun _ => .determined .pos
private def additionalObservation : Unit → Judgment := fun _ => .determined .zero
private def unresolvedObservation : Unit → Judgment := fun _ => .undetermined
private def initialObservations : List (Unit → Judgment) := [resolvedObservation, unresolvedObservation]
private def refinedObservations : List (Unit → Judgment) := [resolvedObservation, additionalObservation]
private def initialEvaluation :
    Evaluation initialObservations (EvaluationContext String String String String Unit) :=
  fun context observation _ => observation context.input
private def refinedEvaluation :
    Evaluation refinedObservations (EvaluationContext String String String String Unit) :=
  fun context observation _ => observation context.input
private def exampleContext : EvaluationContext String String String String Unit := {
  source := "source"
  basis := "basis"
  inputRef := "input"
  certificate := "certificate"
  input := ()
}
private theorem initialEvaluationProof :
    EvaluatedAt initialObservations exampleContext initialEvaluation := by
  intro observation membership
  rfl
private theorem refinedEvaluationProof :
    EvaluatedAt refinedObservations exampleContext refinedEvaluation := by
  intro observation membership
  rfl
private theorem exampleObservationFamilyRefines : ObservationFamilyRefines initialObservations refinedObservations := by
  intro observation membership
  simp [initialObservations] at membership
  rcases membership with resolved | unresolved
  · subst observation
    exact ⟨resolvedObservation, by simp [refinedObservations], RefinesObs.refl⟩
  · subst observation
    exact ⟨additionalObservation, by simp [refinedObservations], fun _ h => False.elim (h rfl)⟩

example : VerifiedRefinement String String String String String String Unit
    initialObservations refinedObservations := {
  source := "source"
  basis := "basis"
  inputRef := "input"
  certificate := "certificate"
  input := ()
  before := { evaluation := initialEvaluation, status := .residual (ResidualSet.ofList ["coordinate"]) }
  after := { evaluation := refinedEvaluation, status := .resolved }
  observationFamilyRefines := exampleObservationFamilyRefines
  evaluatedBefore := initialEvaluationProof
  evaluatedAfter := refinedEvaluationProof
}

example : RefinementResult
    (Evaluation initialObservations (EvaluationContext String String String String Unit)) String String := {
  evaluation := initialEvaluation
  status := .stopped (ResidualSet.ofList ["coordinate"]) "budget"
}

example : ∃ observation, ∃ membership : observation ∈ refinedObservations,
    refinedEvaluation exampleContext observation membership
      = initialEvaluation exampleContext resolvedObservation (by simp [initialObservations]) := by
  have determined :
      initialEvaluation exampleContext resolvedObservation (by simp [initialObservations]) ≠ .undetermined := by
    simp [initialEvaluation, resolvedObservation]
  exact evaluated_determination_preserved exampleObservationFamilyRefines initialEvaluationProof refinedEvaluationProof
    (by simp [initialObservations]) determined

end NecoQuotient
