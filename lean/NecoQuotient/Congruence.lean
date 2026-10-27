import NecoQuotient.Observation

namespace NecoQuotient

universe u v w

variable {X : Type u} {Y : Type w} {V : Type v}

/-- 関数による観測関数族の引き戻し -/
def pullback (f : X → Y) (D : ObservationFamily Y V) : ObservationFamily X V := D.map (fun o => o ∘ f)

/-- 引き戻しの同値は元の観測の同値を含意する -/
theorem respects_pullback (f : X → Y) (D : ObservationFamily Y V) {x y : X} : ObsEquiv (pullback f D) x y → ObsEquiv D (f x) (f y) :=
  fun h o ho => h (o ∘ f) (List.mem_map.mpr ⟨o, ho, rfl⟩)

/-- 引き戻しの同値から商への写像 -/
def lift (f : X → Y) (D : ObservationFamily Y V) : ObsQuotient (pullback f D) → ObsQuotient D :=
  Quotient.lift (fun x => q D (f x)) (fun _ _ h => Quotient.sound (respects_pullback f D h))

/-- 可換図式 q_D ∘ f = lift f ∘ q_(pullback f D) -/
theorem commute (f : X → Y) (D : ObservationFamily Y V) (x : X) : q D (f x) = lift f D (q (pullback f D) x) :=
  rfl

/-- 演算族 F に対する合同 -/
def Congruent (F : List (X → X)) (D : ObservationFamily X V) : Prop :=
  ∀ f, f ∈ F → ∀ x y, ObsEquiv D x y → ObsEquiv D (f x) (f y)

/-- 合同な演算の合成は同値を保つ -/
theorem Congruent.comp {F : List (X → X)} {D : ObservationFamily X V} (h : Congruent F D) {f g : X → X} (hf : f ∈ F) (hg : g ∈ F) {x y : X} : ObsEquiv D x y → ObsEquiv D (g (f x)) (g (f y)) :=
  fun hxy => h g hg _ _ (h f hf x y hxy)

/-- 合同な演算に対する引き戻しの同値 -/
theorem Congruent.pullback_sub {F : List (X → X)} {D : ObservationFamily X V} (h : Congruent F D) {f : X → X} (hf : f ∈ F) {x y : X} : ObsEquiv D x y → ObsEquiv (pullback f D) x y := by
  intro hxy o' ho'
  obtain ⟨o, ho, rfl⟩ := List.mem_map.mp ho'
  exact h f hf x y hxy o ho

/-- 合同な演算の商の上の写像 -/
def liftCongruent {F : List (X → X)} {D : ObservationFamily X V} (h : Congruent F D) {f : X → X} (hf : f ∈ F) : ObsQuotient D → ObsQuotient D :=
  Quotient.lift (fun x => q D (f x)) (fun x y hxy => Quotient.sound (h f hf x y hxy))

/-- 合同な演算の可換図式 q_D ∘ f = liftCongruent ∘ q_D -/
theorem commute_congruent {F : List (X → X)} {D : ObservationFamily X V} (h : Congruent F D) {f : X → X} (hf : f ∈ F) (x : X) : q D (f x) = liftCongruent h hf (q D x) :=
  rfl

/-- 入力側の観測関数族 D から出力側の観測関数族 D_Y への演算 f の合同 -/
def CongruentMap (f : X → Y) (D : ObservationFamily X V) (DY : ObservationFamily Y V) : Prop := ∀ x y, ObsEquiv D x y → ObsEquiv DY (f x) (f y)

/-- 合同な演算の商の上の写像 -/
def liftMap {f : X → Y} {D : ObservationFamily X V} {DY : ObservationFamily Y V} (h : CongruentMap f D DY) : ObsQuotient D → ObsQuotient DY :=
  Quotient.lift (fun x => q DY (f x)) (fun x y hxy => Quotient.sound (h x y hxy))

/-- 可換図式 q_DY ∘ f = liftMap h ∘ q_D -/
theorem commute_map {f : X → Y} {D : ObservationFamily X V} {DY : ObservationFamily Y V} (h : CongruentMap f D DY) (x : X) : q DY (f x) = liftMap h (q D x) :=
  rfl

/-- 引き戻しは合同の証拠を与える -/
theorem pullback_congruentMap (f : X → Y) (DY : ObservationFamily Y V) : CongruentMap f (pullback f DY) DY :=
  fun _ _ h => respects_pullback f DY h

end NecoQuotient
