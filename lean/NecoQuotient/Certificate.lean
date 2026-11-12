namespace NecoQuotient

structure ResidualSet (R : Type) where
  private mk ::
  values : List R

def ResidualSet.deduplicate {R : Type} [DecidableEq R] : List R → List R
  | [] => []
  | value :: rest =>
    if value ∈ rest then ResidualSet.deduplicate rest
    else value :: ResidualSet.deduplicate rest

def ResidualSet.ofList {R : Type} [DecidableEq R] (values : List R) : ResidualSet R :=
  ⟨ResidualSet.deduplicate values⟩

def ResidualSet.contains {R : Type} [DecidableEq R] : List R → R → Bool
  | [], _ => false
  | head :: rest, value => if head = value then true else ResidualSet.contains rest value

def ResidualSet.same {R : Type} [DecidableEq R] (left right : ResidualSet R) : Bool :=
  left.values.all (fun value => ResidualSet.contains right.values value)
    && right.values.all (fun value => ResidualSet.contains left.values value)

#guard ResidualSet.same (ResidualSet.ofList ["b", "a", "a"]) (ResidualSet.ofList ["a", "b"]) == true
#guard ResidualSet.same (ResidualSet.ofList ["b", "a"]) (ResidualSet.ofList ["a", "c"]) == false

inductive DigestScope where
  | withinRuntime (runtime : String)
  | crossLanguage (encoding : String)
  deriving DecidableEq, Repr

structure ProjectionDigest where
  digest : String
  scope : DigestScope
  deriving DecidableEq, Repr

inductive Distinct {α : Type} : List α → Prop where
  | nil : Distinct []
  | cons {a : α} {l : List α} : a ∉ l → Distinct l → Distinct (a :: l)

instance instDecidableDistinct {α : Type} [DecidableEq α] : (l : List α) → Decidable (Distinct l)
  | [] => isTrue Distinct.nil
  | a :: l =>
    if h : a ∈ l then isFalse (fun hd => by cases hd with | cons hn _ => exact hn h)
    else
      match instDecidableDistinct l with
      | isTrue hl => isTrue (Distinct.cons h hl)
      | isFalse hl => isFalse (fun hd => by cases hd with | cons _ h' => exact hl h')

def lookupEntries {α : Type} : List (String × α) → String → Option α
  | [], _ => none
  | (key, value) :: rest, name => if key = name then some value else lookupEntries rest name

structure NameMap (α : Type) where
  private mk ::
  entries : List (String × α)
  distinct : Distinct (entries.map Prod.fst)

def NameMap.get? {α : Type} (m : NameMap α) (name : String) : Option α :=
  lookupEntries m.entries name

instance {α : Type} : GetElem? (NameMap α) String α (fun m name => (m.get? name).isSome = true) where
  getElem m name h := (m.get? name).get h
  getElem? m name := m.get? name

theorem NameMap.getElem?_eq {α : Type} (m : NameMap α) (name : String) : m[name]? = m.get? name := rfl

def NameMap.empty {α : Type} : NameMap α := ⟨[], Distinct.nil⟩

theorem lookupEntries_none_iff {α : Type} (l : List (String × α)) (name : String) :
    lookupEntries l name = none ↔ name ∉ l.map Prod.fst := by
  induction l with
  | nil => exact ⟨fun _ hm => (nomatch hm), fun _ => rfl⟩
  | cons entry rest ih =>
    obtain ⟨key, value⟩ := entry
    by_cases h : key = name
    · unfold lookupEntries
      rw [if_pos h]
      exact ⟨fun hh => (nomatch hh), fun hn => (hn (h ▸ List.Mem.head _)).elim⟩
    · unfold lookupEntries
      rw [if_neg h]
      constructor
      · intro hr hm
        cases hm with
        | head => exact h rfl
        | tail _ hm' => exact ih.1 hr hm'
      · intro hn
        exact ih.2 (fun hm => hn (List.Mem.tail _ hm))

theorem mem_map_fst {α : Type} {l : List (String × α)} {name : String} {value : α} (h : (name, value) ∈ l) :
    name ∈ l.map Prod.fst := by
  induction l with
  | nil => exact nomatch h
  | cons entry rest ih =>
    cases h with
    | head => exact List.Mem.head _
    | tail _ hm => exact List.Mem.tail _ (ih hm)

theorem mem_lookupEntries_iff {α : Type} (l : List (String × α)) (hd : Distinct (l.map Prod.fst)) (name : String) (value : α) :
    (name, value) ∈ l ↔ lookupEntries l name = some value := by
  induction l with
  | nil => exact ⟨fun h => (nomatch h), fun h => (nomatch h)⟩
  | cons entry rest ih =>
    obtain ⟨key, v⟩ := entry
    cases hd with
    | cons hn hd' =>
      by_cases h : key = name
      · subst h
        unfold lookupEntries
        rw [if_pos rfl]
        constructor
        · intro hm
          cases hm with
          | head => rfl
          | tail _ hm' => exact (hn (mem_map_fst hm')).elim
        · intro hh
          cases hh
          exact List.Mem.head _
      · unfold lookupEntries
        rw [if_neg h]
        constructor
        · intro hm
          cases hm with
          | head => exact (h rfl).elim
          | tail _ hm' => exact (ih hd').1 hm'
        · intro hh
          exact List.Mem.tail _ ((ih hd').2 hh)

theorem mem_entries_iff {α : Type} (m : NameMap α) (name : String) (value : α) :
    (name, value) ∈ m.entries ↔ m[name]? = some value :=
  mem_lookupEntries_iff m.entries m.distinct name value

def NameMap.consNew {α : Type} (m : NameMap α) (name : String) (value : α) (h : m.get? name = none) : NameMap α :=
  ⟨(name, value) :: m.entries, Distinct.cons ((lookupEntries_none_iff m.entries name).1 h) m.distinct⟩

def NameMap.addNew {α : Type} (m : NameMap α) (name : String) (value : α) : NameMap α :=
  if h : m.get? name = none then m.consNew name value h else m

def NameMap.addAllNew {α : Type} (m : NameMap α) : List (String × α) → NameMap α
  | [] => m
  | (name, value) :: rest => NameMap.addAllNew (m.addNew name value) rest

def NameMap.mapWith {α β : Type} (f : String → α → β) (m : NameMap α) : NameMap β :=
  ⟨m.entries.map (fun entry => (entry.1, f entry.1 entry.2)), by
    have : (m.entries.map (fun entry => (entry.1, f entry.1 entry.2))).map Prod.fst = m.entries.map Prod.fst := by
      induction m.entries with
      | nil => rfl
      | cons e r ih => simp only [List.map_cons, ih]
    rw [this]
    exact m.distinct⟩

theorem NameMap.addNew_get? {α : Type} (m : NameMap α) (name : String) (value : α) (n : String) :
    (m.addNew name value).get? n = (m.get? n).or (if name = n then some value else none) := by
  unfold NameMap.addNew
  by_cases h : m.get? name = none
  · rw [dif_pos h]
    simp only [NameMap.get?, NameMap.consNew, lookupEntries]
    by_cases hn : name = n
    · subst hn
      have : lookupEntries m.entries name = none := h
      simp [this]
    · simp [hn]
  · rw [dif_neg h]
    by_cases hn : name = n
    · subst hn
      cases hm : m.get? name with
      | none => exact (h hm).elim
      | some v => simp
    · simp [hn]

theorem NameMap.addAllNew_get? {α : Type} (l : List (String × α)) (m : NameMap α) (n : String) :
    (m.addAllNew l).get? n = (m.get? n).or (lookupEntries l n) := by
  induction l generalizing m with
  | nil => simp [NameMap.addAllNew, lookupEntries]
  | cons entry rest ih =>
    obtain ⟨key, value⟩ := entry
    simp only [NameMap.addAllNew, ih, NameMap.addNew_get?, lookupEntries]
    by_cases hk : key = n
    · simp only [hk, if_true]
      cases m.get? n <;> simp
    · simp [hk]

theorem NameMap.mapWith_get? {α β : Type} (f : String → α → β) (m : NameMap α) (n : String) :
    (m.mapWith f).get? n = (m.get? n).map (f n) := by
  obtain ⟨entries, hd⟩ := m
  simp only [NameMap.mapWith, NameMap.get?]
  induction entries with
  | nil => simp [lookupEntries]
  | cons entry rest ih =>
    obtain ⟨key, v⟩ := entry
    by_cases h : key = n
    · subst h; simp [lookupEntries]
    · cases hd with
      | cons _ hd' =>
        simp only [List.map_cons, lookupEntries, h, if_false]
        exact ih hd'

theorem lookupEntries_map {α β : Type} (g : String → α → β) (l : List (String × α)) (n : String) :
    lookupEntries (l.map (fun entry => (entry.1, g entry.1 entry.2))) n = (lookupEntries l n).map (g n) := by
  induction l with
  | nil => simp [lookupEntries]
  | cons entry rest ih =>
    obtain ⟨key, v⟩ := entry
    by_cases h : key = n
    · subst h; simp [lookupEntries]
    · simp [lookupEntries, h, ih]

def nameLE : List Nat → List Nat → Bool
  | [], _ => true
  | _ :: _, [] => false
  | a :: as, b :: bs => if a < b then true else if b < a then false else nameLE as bs

def insertByName {α : Type} (entry : String × α) : List (String × α) → List (String × α)
  | [] => [entry]
  | head :: rest =>
    if nameLE (entry.1.toList.map Char.toNat) (head.1.toList.map Char.toNat) then entry :: head :: rest
    else head :: insertByName entry rest

def sortByName {α : Type} : List (String × α) → List (String × α)
  | [] => []
  | entry :: rest => insertByName entry (sortByName rest)

def NameMap.ofList {α : Type} (l : List (String × α)) : Option (NameMap α) :=
  let sorted := sortByName l
  if h : Distinct (sorted.map Prod.fst) then some ⟨sorted, h⟩ else none

abbrev ProjectionDigests := NameMap ProjectionDigest

structure SourceRef (S Rev : Type) where
  identity : S
  revision : Rev
  deriving DecidableEq

structure Certificate (S Rev C Obs R E : Type) where
  ruleRevision : String
  source : SourceRef S Rev
  coordinate : C
  digests : ProjectionDigests
  residuals : ResidualSet R
  observations : Obs
  evidence : E

structure Expected (S Rev C Obs R : Type) where
  ruleRevision : String
  source : SourceRef S Rev
  coordinate : C
  observations : Obs
  residuals : ResidualSet R

inductive Stage where
  | decode
  | source
  | coordinate
  | observations
  | digest
  | residual
  deriving DecidableEq, Repr

structure Origin where
  ruleRevision : String
  sourceIdentity : String
  sourceRevision : String
  deriving DecidableEq, Repr

def Origin.of {S Rev C Obs R E : Type} [ToString S] [ToString Rev] (c : Certificate S Rev C Obs R E) : Origin :=
  { ruleRevision := c.ruleRevision, sourceIdentity := toString c.source.identity, sourceRevision := toString c.source.revision }

structure ConditionFailure (stage : Stage) (P : Type) where
  operation : String
  expected : String
  actual : String
  origin : Origin
  provenance : P

inductive Prerequisite (Failure Children : Type) where
  | failed (failure : Failure)
  | established (children : Children)

inductive CheckResult (Failure : Type) where
  | matched
  | mismatched (failure : Failure)

def CheckResult.isMatched {Failure : Type} : CheckResult Failure → Bool
  | .matched => true
  | .mismatched _ => false

structure SourceChecks (P : Type) where
  coordinate : CheckResult (ConditionFailure .coordinate P)
  observations : CheckResult (ConditionFailure .observations P)
  residual : CheckResult (ConditionFailure .residual P)

def SourceChecks.allMatched {P : Type} (s : SourceChecks P) : Bool :=
  s.coordinate.isMatched && s.observations.isMatched && s.residual.isMatched

inductive ProjectionResult where
  | matched (value : ProjectionDigest)
  | certificateOnly (actual : ProjectionDigest)
  | recomputedOnly (expected : ProjectionDigest)
  | different (expected actual : ProjectionDigest)

def ProjectionResult.isMatched : ProjectionResult → Bool
  | .matched _ => true
  | _ => false

def ProjectionResult.both (expected actual : ProjectionDigest) : ProjectionResult :=
  if expected = actual then .matched expected else .different expected actual

def ProjectionResult.ofExpected (expected : ProjectionDigest) : Option ProjectionDigest → ProjectionResult
  | none => .recomputedOnly expected
  | some actual => .both expected actual

def ProjectionResult.ofActual (actual : ProjectionDigest) : Option ProjectionDigest → ProjectionResult
  | none => .certificateOnly actual
  | some expected => .both expected actual

def ProjectionResult.classify : Option ProjectionDigest → Option ProjectionDigest → Option ProjectionResult
  | some expected, actual => some (.ofExpected expected actual)
  | none, some actual => some (.ofActual actual none)
  | none, none => none

abbrev DigestChecks := NameMap ProjectionResult

def DigestChecks.check (expected actual : ProjectionDigests) : DigestChecks :=
  (expected.mapWith fun name value => ProjectionResult.ofExpected value actual[name]?).addAllNew
    (actual.entries.map fun entry => (entry.1, ProjectionResult.ofActual entry.2 none))

def DigestChecks.allMatched (d : DigestChecks) : Bool :=
  d.entries.all (fun entry => entry.2.isMatched)

structure AdmissionChecks (P : Type) where
  origin : Origin
  provenance : P
  decode : Prerequisite (ConditionFailure .decode P) DigestChecks
  source : Prerequisite (ConditionFailure .source P) (SourceChecks P)

def AdmissionChecks.allMatched {P : Type} (a : AdmissionChecks P) : Bool :=
  (match a.decode with
    | .failed _ => false
    | .established d => d.allMatched) &&
  (match a.source with
    | .failed _ => false
    | .established s => s.allMatched)

structure Mismatch (P : Type) where
  private mk ::
  checks : AdmissionChecks P
  hasFailure : checks.allMatched = false

inductive Condition where
  | decode
  | source
  | coordinate
  | observations
  | digest
  | residual
  deriving DecidableEq, Repr

inductive Status (P : Type) where
  | matched
  | mismatched
  | uncheckedByDecode (failure : ConditionFailure .decode P)
  | uncheckedBySource (failure : ConditionFailure .source P)

def Condition.prerequisite : Condition → Option Condition
  | .decode => none
  | .source => none
  | .digest => some .decode
  | .coordinate => some .source
  | .observations => some .source
  | .residual => some .source

def Status.ofBool {P : Type} (b : Bool) : Status P := if b then .matched else .mismatched

def AdmissionChecks.statusAt {P : Type} (a : AdmissionChecks P) : Condition → Status P
  | .decode =>
    match a.decode with
    | .failed _ => .mismatched
    | .established _ => .matched
  | .source =>
    match a.source with
    | .failed _ => .mismatched
    | .established _ => .matched
  | .digest =>
    match a.decode with
    | .failed f => .uncheckedByDecode f
    | .established d => .ofBool d.allMatched
  | .coordinate =>
    match a.source with
    | .failed f => .uncheckedBySource f
    | .established s => .ofBool s.coordinate.isMatched
  | .observations =>
    match a.source with
    | .failed f => .uncheckedBySource f
    | .established s => .ofBool s.observations.isMatched
  | .residual =>
    match a.source with
    | .failed f => .uncheckedBySource f
    | .established s => .ofBool s.residual.isMatched

def Mismatch.statusAt {P : Type} (m : Mismatch P) (condition : Condition) : Status P :=
  m.checks.statusAt condition

structure Checked (S Rev C Obs R E : Type) [DecidableEq R] where
  private mk ::
  input : Certificate S Rev C Obs R E
  expected : Expected S Rev C Obs R
  recomputed : ProjectionDigests
  ruleRevision_eq : input.ruleRevision = expected.ruleRevision
  source_eq : input.source = expected.source
  coordinate_eq : input.coordinate = expected.coordinate
  observations_eq : input.observations = expected.observations
  digests_eq : ∀ name : String, input.digests[name]? = recomputed[name]?
  residuals_same : ResidualSet.same input.residuals expected.residuals = true

abbrev Recompute (S Rev C Obs E : Type) := SourceRef S Rev → C → Obs → E → ProjectionDigests

abbrev Selected {S Rev C Obs R E : Type} (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) :=
  { _recompute : Recompute S Rev C Obs E // c.ruleRevision = e.ruleRevision }

section Admission

variable {S Rev C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]

def failureOf (stage : Stage) (expected actual : String) (c : Certificate S Rev C Obs R E) (provenance : P) : ConditionFailure stage P :=
  { operation := "admit", expected := expected, actual := actual, origin := Origin.of c, provenance := provenance }

def conditionResult (stage : Stage) (holds : Prop) [Decidable holds] (expected actual : String) (c : Certificate S Rev C Obs R E) (provenance : P) : CheckResult (ConditionFailure stage P) :=
  if holds then .matched else .mismatched (failureOf stage expected actual c provenance)

def sourceText (s : SourceRef S Rev) : String :=
  toString s.identity ++ "@" ++ toString s.revision

def decodeFailure (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (provenance : P) : ConditionFailure .decode P :=
  failureOf .decode e.ruleRevision c.ruleRevision c provenance

def decodeBranch (c : Certificate S Rev C Obs R E) (rule : Except (ConditionFailure .decode P) (Recompute S Rev C Obs E)) :
    Prerequisite (ConditionFailure .decode P) DigestChecks :=
  match rule with
  | .error f => .failed f
  | .ok recompute => .established (DigestChecks.check (recompute c.source c.coordinate c.observations c.evidence) c.digests)

def sourceBranch (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (provenance : P) :
    Prerequisite (ConditionFailure .source P) (SourceChecks P) :=
  if c.source = e.source then
    .established
      { coordinate := conditionResult .coordinate (c.coordinate = e.coordinate) (toString e.coordinate) (toString c.coordinate) c provenance
        observations := conditionResult .observations (c.observations = e.observations) (toString e.observations) (toString c.observations) c provenance
        residual := conditionResult .residual (ResidualSet.same c.residuals e.residuals = true) (toString e.residuals.values) (toString c.residuals.values) c provenance }
  else .failed (failureOf .source (sourceText e.source) (sourceText c.source) c provenance)

def checksOf (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) : AdmissionChecks P :=
  { origin := Origin.of c
    provenance := provenance
    decode := decodeBranch c (rule.map (·.1))
    source := sourceBranch c e provenance }

omit [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString C] [ToString Obs] [ToString R] in
theorem conditionResult_isMatched (stage : Stage) (holds : Prop) [Decidable holds] (expected actual : String) (c : Certificate S Rev C Obs R E) (provenance : P) :
    (conditionResult stage holds expected actual c provenance).isMatched = true ↔ holds := by
  unfold conditionResult
  split <;> simp [CheckResult.isMatched, *]

omit [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString C] [ToString Obs] [ToString R] in
theorem conditionResult_isMatched_false (stage : Stage) (holds : Prop) [Decidable holds] (expected actual : String) (c : Certificate S Rev C Obs R E) (provenance : P) :
    (conditionResult stage holds expected actual c provenance).isMatched = false ↔ ¬ holds := by
  unfold conditionResult
  split <;> simp [CheckResult.isMatched, *]

theorem Status.ofBool_matched {P : Type} (b : Bool) : (Status.ofBool b : Status P) = .matched ↔ b = true := by
  cases b <;> simp [Status.ofBool]

theorem Status.ofBool_mismatched {P : Type} (b : Bool) : (Status.ofBool b : Status P) = .mismatched ↔ b = false := by
  cases b <;> simp [Status.ofBool]

theorem DigestChecks.check_get? (expected actual : ProjectionDigests) (name : String) :
    (DigestChecks.check expected actual)[name]? = ProjectionResult.classify expected[name]? actual[name]? := by
  have hmap := lookupEntries_map (fun _ a => ProjectionResult.ofActual a none) actual.entries name
  have hget : (DigestChecks.check expected actual)[name]? =
      ((expected.mapWith fun name value => ProjectionResult.ofExpected value actual[name]?).get? name).or
        ((lookupEntries actual.entries name).map (fun a => ProjectionResult.ofActual a none)) := by
    show (DigestChecks.check expected actual).get? name = _
    unfold DigestChecks.check
    rw [NameMap.addAllNew_get?]
    exact congrArg _ hmap
  rw [hget, NameMap.mapWith_get?]
  show _ = ProjectionResult.classify (expected.get? name) (actual.get? name)
  show ((expected.get? name).map _ |>.or ((actual.get? name).map _)) = _
  rcases h1 : expected.get? name with _ | e <;> rcases h2 : actual.get? name with _ | a <;>
    simp only [NameMap.getElem?_eq, h2, Option.map, Option.or, ProjectionResult.classify,
      ProjectionResult.ofActual, ProjectionResult.ofExpected]

theorem list_all_iff {α : Type} (p : α → Bool) (l : List α) : l.all p = true ↔ ∀ x, x ∈ l → p x = true := by
  induction l with
  | nil => exact ⟨fun _ _ hm => (nomatch hm), fun _ => rfl⟩
  | cons a rest ih =>
    constructor
    · intro h x hx
      have h' : (p a && rest.all p) = true := h
      cases hpa : p a with
      | false => rw [hpa] at h'; cases h'
      | true =>
        rw [hpa] at h'
        cases hx with
        | head => exact hpa
        | tail _ hm => exact ih.1 h' x hm
    · intro h
      have hpa : p a = true := h a (List.Mem.head _)
      have hr : rest.all p = true := ih.2 (fun x hx => h x (List.Mem.tail _ hx))
      show (p a && rest.all p) = true
      rw [hpa, hr]
      rfl

theorem bool_eq_false_iff {b : Bool} {P : Prop} (h : b = true ↔ P) : b = false ↔ ¬ P := by
  cases b with
  | false => exact ⟨fun _ hp => (nomatch (h.2 hp)), fun _ => rfl⟩
  | true => exact ⟨fun hh => (nomatch hh), fun hn => (hn (h.1 rfl)).elim⟩

theorem DigestChecks.allMatched_iff (expected actual : ProjectionDigests) :
    (DigestChecks.check expected actual).allMatched = true ↔ ∀ name : String, actual[name]? = expected[name]? := by
  unfold DigestChecks.allMatched
  rw [list_all_iff]
  constructor
  · intro h name
    rcases h1 : expected[name]? with _ | e <;> rcases h2 : actual[name]? with _ | a
    · rfl
    · have hm : (name, ProjectionResult.certificateOnly a) ∈ (DigestChecks.check expected actual).entries :=
        (mem_entries_iff _ _ _).2 (by rw [DigestChecks.check_get?, h1, h2]; rfl)
      have := h _ hm
      exact nomatch this
    · have hm : (name, ProjectionResult.recomputedOnly e) ∈ (DigestChecks.check expected actual).entries :=
        (mem_entries_iff _ _ _).2 (by rw [DigestChecks.check_get?, h1, h2]; rfl)
      have := h _ hm
      exact nomatch this
    · by_cases hea : e = a
      · rw [hea]
      · have hm : (name, ProjectionResult.different e a) ∈ (DigestChecks.check expected actual).entries :=
          (mem_entries_iff _ _ _).2 (by
            rw [DigestChecks.check_get?, h1, h2]
            show some (ProjectionResult.both e a) = _
            unfold ProjectionResult.both
            rw [if_neg hea])
        have := h _ hm
        exact nomatch this
  · intro h entry hentry
    obtain ⟨name, r⟩ := entry
    have hr := (mem_entries_iff _ _ _).1 hentry
    rw [DigestChecks.check_get?] at hr
    have hn := h name
    rcases h1 : expected[name]? with _ | e <;> rcases h2 : actual[name]? with _ | a <;>
      rw [h1, h2] at hr <;> rw [h1, h2] at hn
    · exact nomatch hr
    · exact nomatch hn
    · exact nomatch hn
    · have hae : a = e := Option.some.inj hn
      subst hae
      have hr' : ProjectionResult.both a a = r := Option.some.inj hr
      subst hr'
      show (ProjectionResult.both a a).isMatched = true
      unfold ProjectionResult.both
      rw [if_pos rfl]
      rfl

theorem DigestChecks.allMatched_false_iff (expected actual : ProjectionDigests) :
    (DigestChecks.check expected actual).allMatched = false ↔ ¬ ∀ name : String, actual[name]? = expected[name]? :=
  bool_eq_false_iff (DigestChecks.allMatched_iff expected actual)

theorem and_true_iff : ∀ a b : Bool, (a && b) = true ↔ a = true ∧ b = true
  | true, true => ⟨fun _ => ⟨rfl, rfl⟩, fun _ => rfl⟩
  | true, false => ⟨fun h => (nomatch h), fun h => (nomatch h.2)⟩
  | false, true => ⟨fun h => (nomatch h), fun h => (nomatch h.1)⟩
  | false, false => ⟨fun h => (nomatch h), fun h => (nomatch h.1)⟩

theorem and_false' (a : Bool) : (a && false) = false := by cases a <;> rfl

theorem checksOf_allMatched_ok (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (s : Selected c e) (provenance : P) :
    (checksOf c e (.ok s) provenance).allMatched = true ↔
      (∀ name : String, c.digests[name]? = (s.1 c.source c.coordinate c.observations c.evidence)[name]?) ∧
        c.source = e.source ∧ c.coordinate = e.coordinate ∧ c.observations = e.observations ∧
        ResidualSet.same c.residuals e.residuals = true := by
  unfold AdmissionChecks.allMatched checksOf decodeBranch sourceBranch
  by_cases hs : c.source = e.source
  · rw [if_pos hs]
    show (DigestChecks.allMatched _ &&
      ((conditionResult .coordinate (c.coordinate = e.coordinate) (toString e.coordinate) (toString c.coordinate) c provenance).isMatched &&
      (conditionResult .observations (c.observations = e.observations) (toString e.observations) (toString c.observations) c provenance).isMatched &&
      (conditionResult .residual (ResidualSet.same c.residuals e.residuals = true) (toString e.residuals.values) (toString c.residuals.values) c provenance).isMatched)) = true ↔ _
    rw [and_true_iff, and_true_iff, and_true_iff, conditionResult_isMatched, conditionResult_isMatched, conditionResult_isMatched,
      DigestChecks.allMatched_iff]
    exact ⟨fun ⟨hd, ⟨hc, ho⟩, hr⟩ => ⟨hd, hs, hc, ho, hr⟩, fun ⟨hd, _, hc, ho, hr⟩ => ⟨hd, ⟨hc, ho⟩, hr⟩⟩
  · rw [if_neg hs]
    show (_ && false) = true ↔ _
    rw [and_false']
    exact ⟨fun h => (nomatch h), fun h => (hs h.2.1).elim⟩

def admitSelected (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) : Except (Mismatch P) (Checked S Rev C Obs R E) :=
  match rule with
  | .error f => .error ⟨checksOf c e (.error f) provenance, by simp [checksOf, decodeBranch, sourceBranch, Except.map, AdmissionChecks.allMatched]⟩
  | .ok s =>
    if h : (checksOf c e (.ok s) provenance).allMatched = true then
      .ok (Checked.mk c e (s.1 c.source c.coordinate c.observations c.evidence) s.2
        ((checksOf_allMatched_ok c e s provenance).1 h).2.1 ((checksOf_allMatched_ok c e s provenance).1 h).2.2.1
        ((checksOf_allMatched_ok c e s provenance).1 h).2.2.2.1 ((checksOf_allMatched_ok c e s provenance).1 h).1
        ((checksOf_allMatched_ok c e s provenance).1 h).2.2.2.2)
    else .error ⟨checksOf c e (.ok s) provenance, by simpa using h⟩


def selectDirect (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (recompute : Recompute S Rev C Obs E) (provenance : P) :
    Except (ConditionFailure .decode P) (Selected c e) :=
  if h : c.ruleRevision = e.ruleRevision then .ok ⟨recompute, h⟩ else .error (decodeFailure c e provenance)

def admit (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (recompute : Recompute S Rev C Obs E) (provenance : P) :
    Except (Mismatch P) (Checked S Rev C Obs R E) :=
  admitSelected c e (selectDirect c e recompute provenance) provenance

def holdsAt (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) : Condition → Prop
  | .decode => ∃ s, rule = .ok s
  | .source => c.source = e.source
  | .coordinate => c.coordinate = e.coordinate
  | .observations => c.observations = e.observations
  | .digest =>
    match rule with
    | .ok s => ∀ name : String, c.digests[name]? = (s.1 c.source c.coordinate c.observations c.evidence)[name]?
    | .error _ => False
  | .residual => ResidualSet.same c.residuals e.residuals = true

def prerequisiteHolds (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (condition : Condition) : Prop :=
  match condition.prerequisite with
  | none => True
  | some p => holdsAt c e rule p

theorem statusAt_matched_iff (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) (condition : Condition) :
    (checksOf c e rule provenance).statusAt condition = .matched ↔
      prerequisiteHolds c e rule condition ∧ holdsAt c e rule condition := by
  cases condition <;> cases rule <;> by_cases hs : c.source = e.source <;>
    simp [AdmissionChecks.statusAt, checksOf, decodeBranch, sourceBranch, Except.map, prerequisiteHolds, holdsAt, Condition.prerequisite, hs,
      Status.ofBool_matched, DigestChecks.allMatched_iff, conditionResult_isMatched]


theorem statusAt_mismatched_iff (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) (condition : Condition) :
    (checksOf c e rule provenance).statusAt condition = .mismatched ↔
      prerequisiteHolds c e rule condition ∧ ¬ holdsAt c e rule condition := by
  cases condition <;> cases rule <;> by_cases hs : c.source = e.source <;>
    simp [AdmissionChecks.statusAt, checksOf, decodeBranch, sourceBranch, Except.map, prerequisiteHolds, holdsAt, Condition.prerequisite, hs,
      Status.ofBool_mismatched, DigestChecks.allMatched_false_iff, conditionResult_isMatched_false, -Classical.not_forall]

theorem statusAt_unchecked_decode (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) (condition : Condition)
    (f : ConditionFailure .decode P) :
    (checksOf c e rule provenance).statusAt condition = .uncheckedByDecode f ↔
      condition.prerequisite = some .decode ∧ rule = .error f := by
  cases condition <;> cases rule <;> by_cases hs : c.source = e.source <;>
    simp [AdmissionChecks.statusAt, checksOf, decodeBranch, sourceBranch, Except.map, Condition.prerequisite, hs, Status.ofBool]
  all_goals first | (split <;> simp) | skip

theorem statusAt_unchecked_source (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) (condition : Condition)
    (f : ConditionFailure .source P) :
    (checksOf c e rule provenance).statusAt condition = .uncheckedBySource f ↔
      condition.prerequisite = some .source ∧ c.source ≠ e.source ∧
        f = failureOf .source (sourceText e.source) (sourceText c.source) c provenance := by
  cases condition <;> cases rule <;> by_cases hs : c.source = e.source <;>
    simp [AdmissionChecks.statusAt, checksOf, decodeBranch, sourceBranch, Except.map, Condition.prerequisite, hs, Status.ofBool]
  all_goals first | exact eq_comm | (split <;> simp) | skip


theorem admitSelected_error_checks {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R}
    {rule : Except (ConditionFailure .decode P) (Selected c e)} {provenance : P} {m : Mismatch P}
    (h : admitSelected c e rule provenance = .error m) : m.checks = checksOf c e rule provenance := by
  unfold admitSelected at h
  split at h
  · cases h; rfl
  · split at h
    · cases h
    · cases h; rfl

theorem admitSelected_ok_checks {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R}
    {rule : Except (ConditionFailure .decode P) (Selected c e)} {provenance : P} {k : Checked S Rev C Obs R E}
    (h : admitSelected c e rule provenance = .ok k) :
    ∃ s, rule = .ok s ∧ k.input = c ∧ k.expected = e ∧ k.recomputed = s.1 c.source c.coordinate c.observations c.evidence := by
  unfold admitSelected at h
  split at h
  · cases h
  · rename_i s
    split at h
    · cases h; exact ⟨_, rfl, rfl, rfl, rfl⟩
    · cases h

theorem admitSelected_ok_iff (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) :
    (∃ k, admitSelected c e rule provenance = .ok k) ↔
      holdsAt c e rule .decode ∧ holdsAt c e rule .source ∧ holdsAt c e rule .coordinate ∧
        holdsAt c e rule .observations ∧ holdsAt c e rule .digest ∧ holdsAt c e rule .residual := by
  cases rule with
  | error f =>
    exact ⟨fun ⟨_, hk⟩ => (nomatch hk), fun ⟨⟨_, hs⟩, _⟩ => (nomatch hs)⟩
  | ok s =>
    by_cases h : (checksOf c e (.ok s) provenance).allMatched = true
    · obtain ⟨h1, h2, h3, h4, h5⟩ := (checksOf_allMatched_ok c e s provenance).1 h
      simp only [admitSelected]
      rw [dif_pos h]
      exact ⟨fun _ => ⟨⟨s, rfl⟩, h2, h3, h4, h1, h5⟩, fun _ => ⟨_, rfl⟩⟩
    · simp only [admitSelected]
      rw [dif_neg h]
      constructor
      · rintro ⟨k, hk⟩
        cases hk
      · rintro ⟨-, h2, h3, h4, h1, h5⟩
        exact absurd ((checksOf_allMatched_ok c e s provenance).2 ⟨h1, h2, h3, h4, h5⟩) h

theorem admitSelected_error_iff (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) :
    (∃ m, admitSelected c e rule provenance = .error m) ↔
      ¬ (holdsAt c e rule .decode ∧ holdsAt c e rule .source ∧ holdsAt c e rule .coordinate ∧
        holdsAt c e rule .observations ∧ holdsAt c e rule .digest ∧ holdsAt c e rule .residual) := by
  have key := admitSelected_ok_iff c e rule provenance
  constructor
  · rintro ⟨m, hm⟩ hall
    obtain ⟨k, hk⟩ := key.2 hall
    rw [hk] at hm
    cases hm
  · intro hn
    cases hr : admitSelected c e rule provenance with
    | error m => exact ⟨m, rfl⟩
    | ok k => exact (hn (key.1 ⟨k, hr⟩)).elim

theorem admitSelected_error_sound {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R}
    {rule : Except (ConditionFailure .decode P) (Selected c e)} {provenance : P} {m : Mismatch P}
    (h : admitSelected c e rule provenance = .error m) (condition : Condition) :
    m.statusAt condition = .mismatched → prerequisiteHolds c e rule condition ∧ ¬ holdsAt c e rule condition := by
  unfold Mismatch.statusAt
  rw [admitSelected_error_checks h]
  exact (statusAt_mismatched_iff c e rule provenance condition).1

theorem admitSelected_error_complete {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R}
    {rule : Except (ConditionFailure .decode P) (Selected c e)} {provenance : P} {m : Mismatch P}
    (h : admitSelected c e rule provenance = .error m) (condition : Condition) :
    prerequisiteHolds c e rule condition → ¬ holdsAt c e rule condition → m.statusAt condition = .mismatched := by
  unfold Mismatch.statusAt
  rw [admitSelected_error_checks h]
  exact fun hp hn => (statusAt_mismatched_iff c e rule provenance condition).2 ⟨hp, hn⟩

theorem admitSelected_unchecked_decode {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R}
    {rule : Except (ConditionFailure .decode P) (Selected c e)} {provenance : P} {m : Mismatch P}
    (h : admitSelected c e rule provenance = .error m) (condition : Condition) (f : ConditionFailure .decode P) :
    m.statusAt condition = .uncheckedByDecode f ↔ condition.prerequisite = some .decode ∧ rule = .error f := by
  unfold Mismatch.statusAt
  rw [admitSelected_error_checks h]
  exact statusAt_unchecked_decode c e rule provenance condition f

theorem admitSelected_unchecked_source {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R}
    {rule : Except (ConditionFailure .decode P) (Selected c e)} {provenance : P} {m : Mismatch P}
    (h : admitSelected c e rule provenance = .error m) (condition : Condition) (f : ConditionFailure .source P) :
    m.statusAt condition = .uncheckedBySource f ↔
      condition.prerequisite = some .source ∧ c.source ≠ e.source ∧
        f = failureOf .source (sourceText e.source) (sourceText c.source) c provenance := by
  unfold Mismatch.statusAt
  rw [admitSelected_error_checks h]
  exact statusAt_unchecked_source c e rule provenance condition f


omit [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString C] [ToString Obs] [ToString R] in
theorem selectDirect_of_eq {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} (recompute : Recompute S Rev C Obs E) (provenance : P)
    (h : c.ruleRevision = e.ruleRevision) : selectDirect c e recompute provenance = .ok ⟨recompute, h⟩ := by
  unfold selectDirect
  rw [dif_pos h]

omit [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString C] [ToString Obs] [ToString R] in
theorem selectDirect_of_ne {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} (recompute : Recompute S Rev C Obs E) (provenance : P)
    (h : c.ruleRevision ≠ e.ruleRevision) : selectDirect c e recompute provenance = .error (decodeFailure c e provenance) := by
  unfold selectDirect
  rw [dif_neg h]

theorem admit_ok_iff {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : Recompute S Rev C Obs E} {provenance : P} :
    (∃ k, admit c e recompute provenance = .ok k) ↔
      (c.ruleRevision = e.ruleRevision ∧ c.source = e.source ∧ c.coordinate = e.coordinate ∧ c.observations = e.observations ∧
        (∀ name : String, c.digests[name]? = (recompute c.source c.coordinate c.observations c.evidence)[name]?) ∧
        ResidualSet.same c.residuals e.residuals = true) := by
  unfold admit
  rw [admitSelected_ok_iff]
  by_cases h : c.ruleRevision = e.ruleRevision
  · rw [selectDirect_of_eq recompute provenance h]
    exact ⟨fun ⟨_, a, b, c, d, e⟩ => ⟨h, a, b, c, d, e⟩, fun ⟨_, a, b, c, d, e⟩ => ⟨⟨_, rfl⟩, a, b, c, d, e⟩⟩
  · rw [selectDirect_of_ne recompute provenance h]
    exact ⟨fun ⟨⟨_, hs⟩, _⟩ => (nomatch hs), fun ⟨hh, _⟩ => (h hh).elim⟩

theorem admit_complete {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : Recompute S Rev C Obs E} {provenance : P}
    (h1 : c.ruleRevision = e.ruleRevision) (h2 : c.source = e.source) (h3 : c.coordinate = e.coordinate)
    (h4 : c.observations = e.observations)
    (h5 : ∀ name : String, c.digests[name]? = (recompute c.source c.coordinate c.observations c.evidence)[name]?)
    (h6 : ResidualSet.same c.residuals e.residuals = true) : ∃ k, admit c e recompute provenance = .ok k :=
  admit_ok_iff.2 ⟨h1, h2, h3, h4, h5, h6⟩

theorem admit_sound {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : Recompute S Rev C Obs E} {provenance : P}
    {k : Checked S Rev C Obs R E} (h : admit c e recompute provenance = .ok k) :
    k.input = c ∧ k.expected = e ∧ k.recomputed = recompute c.source c.coordinate c.observations c.evidence := by
  unfold admit at h
  obtain ⟨s, hs, h1, h2, h3⟩ := admitSelected_ok_checks h
  by_cases hv : c.ruleRevision = e.ruleRevision
  · rw [selectDirect_of_eq recompute provenance hv] at hs
    cases hs
    exact ⟨h1, h2, h3⟩
  · rw [selectDirect_of_ne recompute provenance hv] at hs
    cases hs

theorem DigestChecks.check_certificateOnly (expected actual : ProjectionDigests) (name : String) (a : ProjectionDigest) :
    (DigestChecks.check expected actual)[name]? = some (.certificateOnly a) ↔ actual[name]? = some a ∧ expected[name]? = none := by
  rw [DigestChecks.check_get?]
  rcases h1 : expected[name]? with _ | e <;> rcases h2 : actual[name]? with _ | b <;>
    simp [ProjectionResult.classify, ProjectionResult.ofActual, ProjectionResult.ofExpected, ProjectionResult.both] <;>
    split <;> simp

theorem DigestChecks.check_recomputedOnly (expected actual : ProjectionDigests) (name : String) (e : ProjectionDigest) :
    (DigestChecks.check expected actual)[name]? = some (.recomputedOnly e) ↔ expected[name]? = some e ∧ actual[name]? = none := by
  rw [DigestChecks.check_get?]
  rcases h1 : expected[name]? with _ | x <;> rcases h2 : actual[name]? with _ | b <;>
    simp [ProjectionResult.classify, ProjectionResult.ofActual, ProjectionResult.ofExpected, ProjectionResult.both] <;>
    split <;> simp

theorem DigestChecks.check_matched (expected actual : ProjectionDigests) (name : String) (v : ProjectionDigest) :
    (DigestChecks.check expected actual)[name]? = some (.matched v) ↔ expected[name]? = some v ∧ actual[name]? = some v := by
  rw [DigestChecks.check_get?]
  rcases h1 : expected[name]? with _ | x <;> rcases h2 : actual[name]? with _ | y <;>
    simp [ProjectionResult.classify, ProjectionResult.ofActual, ProjectionResult.ofExpected, ProjectionResult.both]
  by_cases hxy : x = y
  · subst hxy; simp
  · simp [hxy]
    intro hx hy
    exact hxy (hx.trans hy.symm)

theorem DigestChecks.check_different (expected actual : ProjectionDigests) (name : String) (e a : ProjectionDigest) :
    (DigestChecks.check expected actual)[name]? = some (.different e a) ↔
      expected[name]? = some e ∧ actual[name]? = some a ∧ e ≠ a := by
  rw [DigestChecks.check_get?]
  rcases h1 : expected[name]? with _ | x <;> rcases h2 : actual[name]? with _ | y <;>
    simp [ProjectionResult.classify, ProjectionResult.ofActual, ProjectionResult.ofExpected, ProjectionResult.both]
  by_cases hxy : x = y <;> simp [hxy] <;> intros <;> simp_all

theorem DigestChecks.check_none (expected actual : ProjectionDigests) (name : String) :
    (DigestChecks.check expected actual)[name]? = none ↔ expected[name]? = none ∧ actual[name]? = none := by
  rw [DigestChecks.check_get?]
  rcases h1 : expected[name]? with _ | x <;> rcases h2 : actual[name]? with _ | b <;>
    simp [ProjectionResult.classify, ProjectionResult.ofActual, ProjectionResult.ofExpected]


theorem checksOf_decode (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) :
    (checksOf c e rule provenance).decode = decodeBranch c (rule.map (·.1)) := rfl

theorem checksOf_source (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P) :
    (checksOf c e rule provenance).source = sourceBranch c e provenance := rfl

theorem statusAt_coordinate_independent {c c' : Certificate S Rev C Obs R E} {e e' : Expected S Rev C Obs R}
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (rule' : Except (ConditionFailure .decode P) (Selected c' e')) (provenance : P)
    (hr : c.ruleRevision = c'.ruleRevision) (hs : c.source = c'.source) (hc : c.coordinate = c'.coordinate)
    (hes : e.source = e'.source) (hec : e.coordinate = e'.coordinate) :
    (checksOf c e rule provenance).statusAt .coordinate = (checksOf c' e' rule' provenance).statusAt .coordinate := by
  by_cases hse : c'.source = e'.source <;>
    simp [AdmissionChecks.statusAt, checksOf, sourceBranch, conditionResult, failureOf, Origin.of, sourceText, hse, hr, hs, hc, hes, hec]

theorem statusAt_observations_independent {c c' : Certificate S Rev C Obs R E} {e e' : Expected S Rev C Obs R}
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (rule' : Except (ConditionFailure .decode P) (Selected c' e')) (provenance : P)
    (hr : c.ruleRevision = c'.ruleRevision) (hs : c.source = c'.source) (ho : c.observations = c'.observations)
    (hes : e.source = e'.source) (heo : e.observations = e'.observations) :
    (checksOf c e rule provenance).statusAt .observations = (checksOf c' e' rule' provenance).statusAt .observations := by
  by_cases hse : c'.source = e'.source <;>
    simp [AdmissionChecks.statusAt, checksOf, sourceBranch, conditionResult, failureOf, Origin.of, sourceText, hse, hr, hs, ho, hes, heo]

theorem statusAt_residual_independent {c c' : Certificate S Rev C Obs R E} {e e' : Expected S Rev C Obs R}
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (rule' : Except (ConditionFailure .decode P) (Selected c' e')) (provenance : P)
    (hr : c.ruleRevision = c'.ruleRevision) (hs : c.source = c'.source) (hres : c.residuals = c'.residuals)
    (hes : e.source = e'.source) (her : e.residuals = e'.residuals) :
    (checksOf c e rule provenance).statusAt .residual = (checksOf c' e' rule' provenance).statusAt .residual := by
  by_cases hse : c'.source = e'.source <;>
    simp [AdmissionChecks.statusAt, checksOf, sourceBranch, conditionResult, failureOf, Origin.of, sourceText, hse, hr, hs, hres, hes, her]

theorem checksOf_provenance (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R)
    (rule : Except (ConditionFailure .decode P) (Selected c e)) (provenance : P)
    (hrule : ∀ f, rule = .error f → f.origin = Origin.of c ∧ f.provenance = provenance) :
    (checksOf c e rule provenance).origin = Origin.of c ∧ (checksOf c e rule provenance).provenance = provenance ∧
      (∀ f, (checksOf c e rule provenance).decode = .failed f → f.origin = Origin.of c ∧ f.provenance = provenance) ∧
      (∀ f, (checksOf c e rule provenance).source = .failed f → f.origin = Origin.of c ∧ f.provenance = provenance) ∧
      (∀ sc, (checksOf c e rule provenance).source = .established sc →
        (∀ f, sc.coordinate = .mismatched f → f.origin = Origin.of c ∧ f.provenance = provenance) ∧
        (∀ f, sc.observations = .mismatched f → f.origin = Origin.of c ∧ f.provenance = provenance) ∧
        (∀ f, sc.residual = .mismatched f → f.origin = Origin.of c ∧ f.provenance = provenance)) := by
  refine ⟨rfl, rfl, ?_, ?_, ?_⟩
  · intro f hf
    cases rule with
    | error g =>
      simp only [checksOf, decodeBranch, Except.map] at hf
      cases hf
      exact hrule _ rfl
    | ok s =>
      simp [checksOf, decodeBranch, Except.map] at hf
  · intro f hf
    simp only [checksOf, sourceBranch] at hf
    split at hf
    · cases hf
    · cases hf
      exact ⟨rfl, rfl⟩
  · intro sc hsc
    simp only [checksOf, sourceBranch] at hsc
    split at hsc
    · cases hsc
      refine ⟨?_, ?_, ?_⟩ <;> intro f hf <;> simp only [conditionResult] at hf <;> split at hf <;> first | (cases hf; done) | (cases hf; exact ⟨rfl, rfl⟩)
    · cases hsc

omit [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString C] [ToString Obs] [ToString R] in
theorem selectDirect_provenance (c : Certificate S Rev C Obs R E) (e : Expected S Rev C Obs R) (recompute : Recompute S Rev C Obs E) (provenance : P) :
    ∀ f, selectDirect c e recompute provenance = .error f → f.origin = Origin.of c ∧ f.provenance = provenance := by
  intro f hf
  unfold selectDirect at hf
  split at hf
  · cases hf
  · cases hf
    exact ⟨rfl, rfl⟩

theorem admit_provenance {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R} {recompute : Recompute S Rev C Obs E} {provenance : P}
    {m : Mismatch P} (h : admit c e recompute provenance = .error m) :
    m.checks.origin = Origin.of c ∧ m.checks.provenance = provenance ∧
      (∀ f, m.checks.decode = .failed f → f.origin = Origin.of c ∧ f.provenance = provenance) ∧
      (∀ f, m.checks.source = .failed f → f.origin = Origin.of c ∧ f.provenance = provenance) ∧
      (∀ sc, m.checks.source = .established sc →
        (∀ f, sc.coordinate = .mismatched f → f.origin = Origin.of c ∧ f.provenance = provenance) ∧
        (∀ f, sc.observations = .mismatched f → f.origin = Origin.of c ∧ f.provenance = provenance) ∧
        (∀ f, sc.residual = .mismatched f → f.origin = Origin.of c ∧ f.provenance = provenance)) := by
  unfold admit at h
  rw [admitSelected_error_checks h]
  exact checksOf_provenance c e _ provenance (selectDirect_provenance c e recompute provenance)


theorem admitSelected_of_decode_error {c : Certificate S Rev C Obs R E} {e : Expected S Rev C Obs R}
    {rule : Except (ConditionFailure .decode P) (Selected c e)} {provenance : P} {f : ConditionFailure .decode P}
    (h : rule = .error f) :
    ∃ m, admitSelected c e rule provenance = .error m ∧ m.statusAt .decode = .mismatched ∧
      m.statusAt .digest = .uncheckedByDecode f := by
  subst h
  refine ⟨⟨checksOf c e (.error f) provenance, by simp [checksOf, decodeBranch, AdmissionChecks.allMatched, Except.map]⟩, rfl, ?_, ?_⟩
  · simp [Mismatch.statusAt, AdmissionChecks.statusAt, checksOf, decodeBranch, Except.map]
  · simp [Mismatch.statusAt, AdmissionChecks.statusAt, checksOf, decodeBranch, Except.map]

end Admission

end NecoQuotient
