import NecoQuotient.Observation
import NecoQuotient.Judgment

namespace NecoQuotient

universe u v

variable {X : Type u} {V : Type v} {W : Type v}

/-- 領域の述語と代表の値で表す類 -/
structure Block (X : Type u) (W : Type v) where
  region : X → Prop
  value : W

/-- 細分: P' の各類がある P の類に含まれる -/
def Refines (P' P : List (Block X W)) : Prop :=
  ∀ b', b' ∈ P' → ∃ b, b ∈ P ∧ ∀ x, b'.region x → b.region x

/-- 観測関数族 D と代表 r の類 -/
def classBlock (D : ObservationFamily X V) (r : X) : Block X (List V) :=
  { region := fun y => ObsEquiv D r y, value := D.map (fun o => o r) }

private theorem map_congr_mem {α : Type u} {β : Type v} (f g : α → β) : ∀ (l : List α), (∀ a, a ∈ l → f a = g a) → l.map f = l.map g
  | [], _ => rfl
  | a :: l, h => by
    rw [List.map_cons, List.map_cons, h a (by simp), map_congr_mem f g l (fun b hb => h b (by simp [hb]))]

/-- 類の代表に対する値は類の内の任意の点で一致する -/
theorem classBlock_consistent (D : ObservationFamily X V) (r x : X) : ObsEquiv D r x → D.map (fun o => o x) = (classBlock D r).value := by
  intro h
  exact (map_congr_mem (fun o => o r) (fun o => o x) D (fun o ho => h o ho)).symm

/-- 代表の列が領域を覆うとき、類の列が領域を覆う -/
theorem classBlocks_cover (D : ObservationFamily X V) (reps : List X) (W : X → Prop) (hc : ∀ x, W x → ∃ r, r ∈ reps ∧ ObsEquiv D r x) : ∀ x, W x → ∃ b, b ∈ reps.map (classBlock D) ∧ b.region x := by
  intro x hx
  obtain ⟨r, hr, hrx⟩ := hc x hx
  exact ⟨classBlock D r, List.mem_map.mpr ⟨r, hr, rfl⟩, hrx⟩

/-- 精密化は細分である -/
theorem refine_is_refinement {D D' : ObservationFamily X V} (h : ∀ o, o ∈ D → o ∈ D') (reps reps' : List X) (hc : ∀ r', r' ∈ reps' → ∃ r, r ∈ reps ∧ ObsEquiv D r r') : Refines (reps'.map (classBlock D')) (reps.map (classBlock D)) := by
  intro b' hb'
  obtain ⟨r', hr', rfl⟩ := List.mem_map.mp hb'
  obtain ⟨r, hr, hrr'⟩ := hc r' hr'
  refine ⟨classBlock D r, List.mem_map.mpr ⟨r, hr, rfl⟩, fun x hx => ?_⟩
  have hx' : ObsEquiv D' r' x := hx
  exact ObsEquiv.trans hrr' (ObsEquiv.mono h hx')

/-- 有限の外延による領域 -/
def finiteRegion [DecidableEq X] (members : List X) : X → Prop := fun x => x ∈ members

/-- 区間による領域 -/
def intervalRegion {α : Type u} [Linear α] (I : Interval α) : α → Prop :=
  fun x => Linear.le I.lower x ∧ Linear.le x I.upper

/-- 領域の述語による商: 類の列が領域 W を覆い、各類の中の全ての点が代表の値を持つ -/
structure RegionQuotient (D : ObservationFamily X V) (W : X → Prop) where
  blocks : List (Block X (List V))
  covers : ∀ x, W x → ∃ b, b ∈ blocks ∧ b.region x
  consistent : ∀ b, b ∈ blocks → ∀ x, b.region x → D.map (fun o => o x) = b.value
  saturated : ∀ b, b ∈ blocks → ∀ x y, b.region x → W y → D.map (fun o => o y) = b.value → b.region y
  distinct : (blocks.map (fun b => b.value)).Nodup

private theorem map_eq_pointwise {X : Type u} {V : Type v} {x y : X} (D : List (X → V)) : D.map (fun o => o x) = D.map (fun o => o y) → ∀ o, o ∈ D → o x = o y := by
  induction D with
  | nil => intro _ o ho; cases ho
  | cons a l ih =>
    intro h o ho
    rw [List.map_cons, List.map_cons, List.cons.injEq] at h
    rcases List.mem_cons.mp ho with rfl | hmem
    · exact h.1
    · exact ih h.2 o hmem

private theorem nodup_map_of_inj {α : Type u} {β : Type v} (f : α → β) : ∀ (l : List α), l.Nodup → (∀ x, x ∈ l → ∀ y, y ∈ l → f x = f y → x = y) → (l.map f).Nodup
  | [], _, _ => List.nodup_nil
  | a :: l, hn, hi => by
    rw [List.nodup_cons] at hn
    rw [List.map_cons, List.nodup_cons]
    refine ⟨?_, nodup_map_of_inj f l hn.2 (fun x hx y hy h => hi x (by simp [hx]) y (by simp [hy]) h)⟩
    intro hmem
    obtain ⟨b, hb, hfb⟩ := List.mem_map.mp hmem
    have hab : a = b := hi a (by simp) b (by simp [hb]) hfb.symm
    exact hn.1 (by rw [hab]; exact hb)

/-- 代表の列が領域を覆うとき、ObsEquiv の類は RegionQuotient をなす -/
def classQuotient (D : ObservationFamily X V) (reps : List X) (W : X → Prop) (hc : ∀ x, W x → ∃ r, r ∈ reps ∧ ObsEquiv D r x) (hnodup : reps.Nodup) (hrep : ∀ r r', r ∈ reps → r' ∈ reps → ObsEquiv D r r' → r = r') : RegionQuotient D W :=
  { blocks := reps.map (classBlock D)
    covers := classBlocks_cover D reps W hc
    consistent := fun b hb x hx => by
      obtain ⟨r, _, rfl⟩ := List.mem_map.mp hb
      exact classBlock_consistent D r x hx
    saturated := fun b hb x y _ _ hv => by
      obtain ⟨r, _, rfl⟩ := List.mem_map.mp hb
      exact map_eq_pointwise D (show D.map (fun o => o r) = D.map (fun o => o y) from hv.symm)
    distinct := by
      rw [List.map_map]
      exact nodup_map_of_inj _ reps hnodup
        (fun r hr r' hr' heq => hrep r r' hr hr' (map_eq_pointwise D (show D.map (fun o => o r) = D.map (fun o => o r') from heq)))
        }

/-- 有限の外延は Block の一つの場合である -/
def finiteBlock [DecidableEq X] (members : List X) (value : W) : Block X W := { region := finiteRegion members, value := value }

/-- 有限の外延による一つの類の商 -/
def finiteRegionQuotient [DecidableEq X] (D : ObservationFamily X V) (members : List X) (r : X) (h : ∀ x, x ∈ members → ObsEquiv D r x) : RegionQuotient D (finiteRegion members) :=
  { blocks := [finiteBlock members (D.map (fun o => o r))]
    covers := fun x hx => ⟨finiteBlock members (D.map (fun o => o r)), by simp, hx⟩
    consistent := fun b hb x hx => by
      obtain rfl := List.mem_singleton.mp hb
      exact map_congr_mem (fun o => o x) (fun o => o r) D (fun o ho => (h x hx o ho).symm)
    saturated := fun b hb x y _ hW _ => by
      obtain rfl := List.mem_singleton.mp hb
      exact hW
    distinct := by simp }

/-- 区間は Block の一つの場合である -/
def intervalBlock {α : Type u} [Linear α] (I : Interval α) (value : W) : Block α W := { region := intervalRegion I, value := value }

/-- 区間による一つの類の商 -/
def intervalRegionQuotient {α : Type u} [Linear α] (D : ObservationFamily α V) (I : Interval α) (r : α) (h : ∀ x, intervalRegion I x → ObsEquiv D r x) : RegionQuotient D (intervalRegion I) :=
  { blocks := [intervalBlock I (D.map (fun o => o r))]
    covers := fun x hx => ⟨intervalBlock I (D.map (fun o => o r)), by simp, hx⟩
    consistent := fun b hb x hx => by
      obtain rfl := List.mem_singleton.mp hb
      exact map_congr_mem (fun o => o x) (fun o => o r) D (fun o ho => (h x hx o ho).symm)
    saturated := fun b hb x y _ hW _ => by
      obtain rfl := List.mem_singleton.mp hb
      exact hW
    distinct := by simp }

/-- 領域の述語による商の各類の二点は、観測関数族について同値である -/
theorem RegionQuotient.block_equiv {D : ObservationFamily X V} {W : X → Prop} (Q : RegionQuotient D W) {b : Block X (List V)} (hb : b ∈ Q.blocks) {x y : X} (hx : b.region x) (hy : b.region y) : ObsEquiv D x y :=
  map_eq_pointwise D (by rw [Q.consistent b hb x hx, Q.consistent b hb y hy])

/-- 領域の述語による商の各類は、その任意の点を代表とする ObsEquiv の類に含まれる -/
theorem RegionQuotient.block_subset_classBlock {D : ObservationFamily X V} {W : X → Prop} (Q : RegionQuotient D W) {b : Block X (List V)} (hb : b ∈ Q.blocks) {r : X} (hr : b.region r) : ∀ x, b.region x → (classBlock D r).region x :=
  fun _ hx => Q.block_equiv hb hr hx

end NecoQuotient
