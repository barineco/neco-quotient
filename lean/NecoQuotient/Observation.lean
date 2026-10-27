namespace NecoQuotient

universe u v

variable {X : Type u} {V : Type v}

/-- 観測関数族 -/
abbrev ObservationFamily (X : Type u) (V : Type v) := List (X → V)

/-- D の全ての観測で一致すること -/
def ObsEquiv (D : ObservationFamily X V) (x y : X) : Prop := ∀ o, o ∈ D → o x = o y

/-- 同値関係の反射律 -/
theorem ObsEquiv.refl (D : ObservationFamily X V) (x : X) : ObsEquiv D x x :=
  fun _ _ => rfl

/-- 同値関係の対称律 -/
theorem ObsEquiv.symm {D : ObservationFamily X V} {x y : X} : ObsEquiv D x y → ObsEquiv D y x :=
  fun h o ho => (h o ho).symm

/-- 同値関係の推移律 -/
theorem ObsEquiv.trans {D : ObservationFamily X V} {x y z : X} : ObsEquiv D x y → ObsEquiv D y z → ObsEquiv D x z :=
  fun h1 h2 o ho => (h1 o ho).trans (h2 o ho)

/-- 観測関数族が定める同値関係 -/
def ObsEquiv.setoid (D : ObservationFamily X V) : Setoid X where
  r := ObsEquiv D
  iseqv := ⟨fun x => ObsEquiv.refl D x, fun h => ObsEquiv.symm h, fun h1 h2 => ObsEquiv.trans h1 h2⟩

/-- 観測関数族による商 -/
abbrev ObsQuotient (D : ObservationFamily X V) := Quotient (ObsEquiv.setoid D)

/-- 点の類への写像 -/
def q (D : ObservationFamily X V) (x : X) : ObsQuotient D := Quotient.mk (ObsEquiv.setoid D) x

/-- D ⊆ D' のとき D' の同値は D の同値を含意する -/
theorem ObsEquiv.mono {D D' : ObservationFamily X V} (h : ∀ o, o ∈ D → o ∈ D') {x y : X} : ObsEquiv D' x y → ObsEquiv D x y :=
  fun hxy o ho => hxy o (h o ho)

/-- 精密化で既存の区別が保たれる -/
theorem ObsEquiv.distinct_preserved {D D' : ObservationFamily X V} (h : ∀ o, o ∈ D → o ∈ D') {x y : X} : ¬ ObsEquiv D x y → ¬ ObsEquiv D' x y :=
  fun hn hd => hn (ObsEquiv.mono h hd)

/-- 商の等号は観測の一致と同値 -/
theorem q_eq_iff {D : ObservationFamily X V} {x y : X} : q D x = q D y ↔ ObsEquiv D x y :=
  by
    constructor
    · intro h
      exact Quotient.exact h
    · intro h
      exact Quotient.sound h

/-- 観測関数族を広げた商から元の商への写像 ( 粗視化 ) -/
def coarsen {D D' : ObservationFamily X V} (h : ∀ o, o ∈ D → o ∈ D') : ObsQuotient D' → ObsQuotient D :=
  Quotient.lift (q D) (fun _ _ hxy => Quotient.sound (ObsEquiv.mono h hxy))

/-- 粗視化は点の類を点の類へ写す ( D' の類は D の類を細分する ) -/
theorem coarsen_q {D D' : ObservationFamily X V} (h : ∀ o, o ∈ D → o ∈ D') (x : X) : coarsen h (q D' x) = q D x :=
  rfl

end NecoQuotient
