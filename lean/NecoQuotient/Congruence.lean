import NecoQuotient.Observation

namespace NecoQuotient

universe u v w

variable {X : Type u} {Y : Type w} {V : Type v}

def pullback (f : X → Y) (D : ObservationFamily Y V) : ObservationFamily X V := D.map (fun o => o ∘ f)

theorem respects_pullback (f : X → Y) (D : ObservationFamily Y V) {x y : X} : ObsEquiv (pullback f D) x y → ObsEquiv D (f x) (f y) :=
  fun h o ho => h (o ∘ f) (List.mem_map.mpr ⟨o, ho, rfl⟩)

def lift (f : X → Y) (D : ObservationFamily Y V) : ObsQuotient (pullback f D) → ObsQuotient D :=
  Quotient.lift (fun x => q D (f x)) (fun _ _ h => Quotient.sound (respects_pullback f D h))

theorem commute (f : X → Y) (D : ObservationFamily Y V) (x : X) : q D (f x) = lift f D (q (pullback f D) x) :=
  rfl

def Congruent (F : List (X → X)) (D : ObservationFamily X V) : Prop :=
  ∀ f, f ∈ F → ∀ x y, ObsEquiv D x y → ObsEquiv D (f x) (f y)

theorem Congruent.comp {F : List (X → X)} {D : ObservationFamily X V} (h : Congruent F D) {f g : X → X} (hf : f ∈ F) (hg : g ∈ F) {x y : X} : ObsEquiv D x y → ObsEquiv D (g (f x)) (g (f y)) :=
  fun hxy => h g hg _ _ (h f hf x y hxy)

theorem Congruent.pullback_sub {F : List (X → X)} {D : ObservationFamily X V} (h : Congruent F D) {f : X → X} (hf : f ∈ F) {x y : X} : ObsEquiv D x y → ObsEquiv (pullback f D) x y := by
  intro hxy o' ho'
  obtain ⟨o, ho, rfl⟩ := List.mem_map.mp ho'
  exact h f hf x y hxy o ho

def liftCongruent {F : List (X → X)} {D : ObservationFamily X V} (h : Congruent F D) {f : X → X} (hf : f ∈ F) : ObsQuotient D → ObsQuotient D :=
  Quotient.lift (fun x => q D (f x)) (fun x y hxy => Quotient.sound (h f hf x y hxy))

theorem commute_congruent {F : List (X → X)} {D : ObservationFamily X V} (h : Congruent F D) {f : X → X} (hf : f ∈ F) (x : X) : q D (f x) = liftCongruent h hf (q D x) :=
  rfl

def CongruentMap (f : X → Y) (D : ObservationFamily X V) (DY : ObservationFamily Y V) : Prop := ∀ x y, ObsEquiv D x y → ObsEquiv DY (f x) (f y)

def liftMap {f : X → Y} {D : ObservationFamily X V} {DY : ObservationFamily Y V} (h : CongruentMap f D DY) : ObsQuotient D → ObsQuotient DY :=
  Quotient.lift (fun x => q DY (f x)) (fun x y hxy => Quotient.sound (h x y hxy))

theorem commute_map {f : X → Y} {D : ObservationFamily X V} {DY : ObservationFamily Y V} (h : CongruentMap f D DY) (x : X) : q DY (f x) = liftMap h (q D x) :=
  rfl

theorem pullback_congruentMap (f : X → Y) (DY : ObservationFamily Y V) : CongruentMap f (pullback f DY) DY :=
  fun _ _ h => respects_pullback f DY h

end NecoQuotient
