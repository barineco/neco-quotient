import NecoQuotient.Certificate

namespace NecoQuotient

structure Resolved (S Rev V W : Type) where
  source : SourceRef S Rev
  value : V
  witness : W

structure Resolver (S Rev V W F : Type) where
  resolve : SourceRef S Rev → Except F (Resolved S Rev V W)

structure ExpectedRest (C Obs R : Type) where
  ruleRevision : String
  coordinate : C
  observations : Obs
  residuals : ResidualSet R

def Resolved.expected {S Rev V W C Obs R : Type} (res : Resolved S Rev V W) (rest : ExpectedRest C Obs R) : Expected S Rev C Obs R :=
  { ruleRevision := rest.ruleRevision, source := res.source, coordinate := rest.coordinate, observations := rest.observations, residuals := rest.residuals }

inductive ResolvedAdmitFailure (S Rev F P : Type) where
  | version (failure : ConditionFailure .decode P)
  | resolution (request : SourceRef S Rev) (failure : F) (provenance : P)
  | mismatch (mismatch : Mismatch P)

structure ResolvedChecked (S Rev V W C Obs R E : Type) [DecidableEq R] where
  checked : Checked S Rev C Obs R E
  resolved : Resolved S Rev V W

def admitResolved {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → Recompute S Rev C Obs E) (provenance : P) :
    Except (ResolvedAdmitFailure S Rev F P) (ResolvedChecked S Rev V W C Obs R E) :=
  if c.ruleRevision = rest.ruleRevision then
    match r.resolve c.source with
    | .error f => .error (.resolution c.source f provenance)
    | .ok res =>
      match admit (P := P) c (res.expected rest) (recompute res.value) provenance with
      | .error m => .error (.mismatch m)
      | .ok k => .ok { checked := k, resolved := res }
  else .error (.version (failureOf .decode rest.ruleRevision c.ruleRevision c provenance))

theorem admitResolved_decode_first {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → Recompute S Rev C Obs E) (prov : P)
    (h : c.ruleRevision ≠ rest.ruleRevision) :
    admitResolved (P := P) r c rest recompute prov = .error (.version (failureOf .decode rest.ruleRevision c.ruleRevision c prov)) := by
  unfold admitResolved
  rw [if_neg h]

theorem admitResolved_resolution {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → Recompute S Rev C Obs E) (prov : P) {f : F}
    (h1 : c.ruleRevision = rest.ruleRevision) (h : r.resolve c.source = .error f) :
    admitResolved (P := P) r c rest recompute prov = .error (.resolution c.source f prov) := by
  unfold admitResolved
  rw [if_pos h1, h]

theorem admitResolved_stale {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → Recompute S Rev C Obs E) (prov : P) {res : Resolved S Rev V W}
    (h : r.resolve c.source = .ok res) (h1 : c.ruleRevision = rest.ruleRevision) (h2 : c.source ≠ res.source) :
    ∃ m, admitResolved (P := P) r c rest recompute prov = .error (.mismatch m) ∧ m.statusAt .source = .mismatched := by
  obtain ⟨m, hm⟩ := (admitSelected_error_iff c (res.expected rest) (selectDirect c (res.expected rest) (recompute res.value) prov) prov).2
    (fun hall => h2 hall.2.1)
  have hm' : admit (P := P) c (res.expected rest) (recompute res.value) prov = .error m := hm
  refine ⟨m, ?_, ?_⟩
  · unfold admitResolved
    rw [if_pos h1, h]
    simp only [hm']
  · exact admitSelected_error_complete hm .source trivial (fun hh => h2 hh)

theorem admitResolved_source_eq {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → Recompute S Rev C Obs E) (prov : P) {k : ResolvedChecked S Rev V W C Obs R E}
    (h : admitResolved (P := P) r c rest recompute prov = .ok k) :
    r.resolve c.source = .ok k.resolved ∧ k.checked.input = c ∧ c.source = k.resolved.source ∧
      ∀ name : String, c.digests[name]? = (recompute k.resolved.value c.source c.coordinate c.observations c.evidence)[name]? := by
  unfold admitResolved at h
  split at h
  · cases hr : r.resolve c.source with
    | error f =>
      rw [hr] at h
      cases h
    | ok res =>
      rw [hr] at h
      dsimp only at h
      cases hc : admit (P := P) c (res.expected rest) (recompute res.value) prov with
      | error m =>
        rw [hc] at h
        cases h
      | ok k' =>
        rw [hc] at h
        cases h
        obtain ⟨hi, he, hr'⟩ := admit_sound hc
        have hsrc := k'.source_eq
        rw [hi, he] at hsrc
        refine ⟨rfl, hi, hsrc, fun name => ?_⟩
        have hdig := k'.digests_eq name
        rw [hi, hr'] at hdig
        exact hdig
  · cases h

end NecoQuotient
