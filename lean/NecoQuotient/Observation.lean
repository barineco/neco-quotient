namespace NecoQuotient

universe u v

variable {X : Type u} {V : Type v}

abbrev ObservationFamily (X : Type u) (V : Type v) := List (X → V)

def ObsEquiv (D : ObservationFamily X V) (x y : X) : Prop := ∀ o, o ∈ D → o x = o y

theorem ObsEquiv.refl (D : ObservationFamily X V) (x : X) : ObsEquiv D x x :=
  fun _ _ => rfl

theorem ObsEquiv.symm {D : ObservationFamily X V} {x y : X} : ObsEquiv D x y → ObsEquiv D y x :=
  fun h o ho => (h o ho).symm

theorem ObsEquiv.trans {D : ObservationFamily X V} {x y z : X} : ObsEquiv D x y → ObsEquiv D y z → ObsEquiv D x z :=
  fun h1 h2 o ho => (h1 o ho).trans (h2 o ho)

def ObsEquiv.setoid (D : ObservationFamily X V) : Setoid X where
  r := ObsEquiv D
  iseqv := ⟨fun x => ObsEquiv.refl D x, fun h => ObsEquiv.symm h, fun h1 h2 => ObsEquiv.trans h1 h2⟩

abbrev ObsQuotient (D : ObservationFamily X V) := Quotient (ObsEquiv.setoid D)

def q (D : ObservationFamily X V) (x : X) : ObsQuotient D := Quotient.mk (ObsEquiv.setoid D) x

theorem ObsEquiv.mono {D D' : ObservationFamily X V} (h : ∀ o, o ∈ D → o ∈ D') {x y : X} : ObsEquiv D' x y → ObsEquiv D x y :=
  fun hxy o ho => hxy o (h o ho)

theorem ObsEquiv.distinct_preserved {D D' : ObservationFamily X V} (h : ∀ o, o ∈ D → o ∈ D') {x y : X} : ¬ ObsEquiv D x y → ¬ ObsEquiv D' x y :=
  fun hn hd => hn (ObsEquiv.mono h hd)

theorem q_eq_iff {D : ObservationFamily X V} {x y : X} : q D x = q D y ↔ ObsEquiv D x y :=
  by
    constructor
    · intro h
      exact Quotient.exact h
    · intro h
      exact Quotient.sound h

def coarsen {D D' : ObservationFamily X V} (h : ∀ o, o ∈ D → o ∈ D') : ObsQuotient D' → ObsQuotient D :=
  Quotient.lift (q D) (fun _ _ hxy => Quotient.sound (ObsEquiv.mono h hxy))

theorem coarsen_q {D D' : ObservationFamily X V} (h : ∀ o, o ∈ D → o ∈ D') (x : X) : coarsen h (q D' x) = q D x :=
  rfl

end NecoQuotient
