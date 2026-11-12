import NecoQuotient.Observation
import NecoQuotient.Judgment
import NecoQuotient.Certificate

namespace NecoQuotient

universe u

variable {X : Type u}

theorem RefinesObs.refl {o : X → Judgment} : RefinesObs o o :=
  fun _ _ => rfl

theorem RefinesObs.trans {o o' o'' : X → Judgment} (h1 : RefinesObs o o') (h2 : RefinesObs o' o'') : RefinesObs o o'' :=
  fun x hx => (h2 x (by rw [h1 x hx]; exact hx)).trans (h1 x hx)

def ObservationFamilyRefines (D D' : ObservationFamily X Judgment) : Prop := ∀ o, o ∈ D → ∃ o', o' ∈ D' ∧ RefinesObs o o'

abbrev Evaluation {X : Type u} (D : ObservationFamily X Judgment) (Context : Type u) :=
  Context → (o : X → Judgment) → o ∈ D → Judgment

structure EvaluationContext (Source Basis InputRef CertRef : Type) (X : Type u) where
  source : Source
  basis : Basis
  inputRef : InputRef
  certificate : CertRef
  input : X

def EvaluatedAt {Source Basis InputRef CertRef : Type} {X : Type u}
    (D : ObservationFamily X Judgment)
    (context : EvaluationContext Source Basis InputRef CertRef X)
    (result : Evaluation D (EvaluationContext Source Basis InputRef CertRef X)) : Prop :=
  ∀ o ho, result context o ho = o context.input

inductive RefinementStatus (Residual Stop : Type)
  | resolved
  | residual (residuals : ResidualSet Residual)
  | stopped (residuals : ResidualSet Residual) (cause : Stop)

structure RefinementResult (Result : Type u) (Residual Stop : Type) where
  evaluation : Result
  status : RefinementStatus Residual Stop

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

theorem ObservationFamilyRefines.of_subset {D D' : ObservationFamily X Judgment} (h : ∀ o, o ∈ D → o ∈ D') : ObservationFamilyRefines D D' :=
  fun o ho => ⟨o, h o ho, RefinesObs.refl⟩

theorem ObservationFamilyRefines.trans {D D' D'' : ObservationFamily X Judgment} (h1 : ObservationFamilyRefines D D') (h2 : ObservationFamilyRefines D' D'') : ObservationFamilyRefines D D'' := by
  intro o ho
  obtain ⟨o', ho', hr⟩ := h1 o ho
  obtain ⟨o'', ho'', hr'⟩ := h2 o' ho'
  exact ⟨o'', ho'', RefinesObs.trans hr hr'⟩

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

theorem observationFamilyRefines_distinct_preserved {D D' : ObservationFamily X Judgment} (h : ObservationFamilyRefines D D') {x y : X} {o : X → Judgment} (ho : o ∈ D) (hx : o x ≠ .undetermined) (hy : o y ≠ .undetermined) (hne : o x ≠ o y) : ¬ ObsEquiv D' x y := by
  intro hd
  obtain ⟨o', ho', hr⟩ := h o ho
  have e1 : o' x = o x := hr x hx
  have e2 : o' y = o y := hr y hy
  have hxy : o' x = o' y := hd o' ho'
  rw [e1, e2] at hxy
  exact hne hxy

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
