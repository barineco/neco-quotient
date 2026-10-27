import NecoQuotient.Certificate

namespace NecoQuotient

/-- resolver の観測: 要求した source の参照、値、検証の観測 W -/
structure Resolved (S Rev V W : Type) where
  source : SourceRef S Rev
  value : V
  witness : W

/-- 外部観測の接触点としての resolver: 要求した参照から観測か型付きの失敗を返す。観測が外界で真実であることは証明の外にある -/
structure Resolver (S Rev V W F : Type) where
  resolve : SourceRef S Rev → Except F (Resolved S Rev V W)

/-- resolver の参照を除く期待値の欄 -/
structure ExpectedRest (C Obs R : Type) where
  ruleRevision : String
  coordinate : C
  observations : Obs
  residuals : ResidualSet R

/-- resolver が返した入力参照を用いる期待値 -/
def Resolved.expected {S Rev V W C Obs R : Type} (res : Resolved S Rev V W) (rest : ExpectedRest C Obs R) : Expected S Rev C Obs R :=
  { ruleRevision := rest.ruleRevision, source := res.source, coordinate := rest.coordinate, observations := rest.observations, residuals := rest.residuals }

/-- resolver を経る照合の失敗: 要求した参照と来歴を持つ resolver の失敗と、照合の不一致 -/
inductive ResolvedAdmitFailure (S Rev F P : Type) where
  | resolution (request : SourceRef S Rev) (failure : F) (provenance : P)
  | mismatch (mismatch : Mismatch P)

/-- 受理された照合と、照合が使った resolver の観測 -/
structure ResolvedChecked (S Rev V W C Obs R E : Type) [DecidableEq R] where
  checked : Checked S Rev C Obs R E
  resolved : Resolved S Rev V W

/-- 規則のリビジョンを照合した後に証明書の入力参照を resolver で解決し、resolver の参照を期待値の源、観測した内容を再計算の入力として照合する -/
def admitResolved {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → SourceRef S Rev → C → Obs → E → List ProjectionDigest) (provenance : P) :
    Except (ResolvedAdmitFailure S Rev F P) (ResolvedChecked S Rev V W C Obs R E) :=
  if c.ruleRevision = rest.ruleRevision then
    match r.resolve c.source with
    | .error f => .error (.resolution c.source f provenance)
    | .ok res =>
      match admit (P := P) c (res.expected rest) (recompute res.value) provenance with
      | .error m => .error (.mismatch m)
      | .ok k => .ok { checked := k, resolved := res }
  else .error (.mismatch (Mismatch.mk "admit" .decode rest.ruleRevision c.ruleRevision provenance []))

/-- 規則のリビジョンが異なる時、照合は resolver の結果に依らない decode の段階の不一致を返す -/
theorem admitResolved_decode_first {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → SourceRef S Rev → C → Obs → E → List ProjectionDigest) (prov : P)
    (h : c.ruleRevision ≠ rest.ruleRevision) :
    admitResolved (P := P) r c rest recompute prov = .error (.mismatch (Mismatch.mk "admit" .decode rest.ruleRevision c.ruleRevision prov [])) := by
  unfold admitResolved
  rw [if_neg h]

/-- 規則のリビジョンが一致し resolver が失敗した時、照合は要求した参照と来歴を持つ resolver の失敗を返す -/
theorem admitResolved_resolution {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → SourceRef S Rev → C → Obs → E → List ProjectionDigest) (prov : P) {f : F}
    (h1 : c.ruleRevision = rest.ruleRevision) (h : r.resolve c.source = .error f) :
    admitResolved (P := P) r c rest recompute prov = .error (.resolution c.source f prov) := by
  unfold admitResolved
  rw [if_pos h1, h]

/-- resolver の参照が証明書の入力参照と異なり規則のリビジョンが一致する時、照合は source の段階の不一致を返す -/
theorem admitResolved_stale {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → SourceRef S Rev → C → Obs → E → List ProjectionDigest) (prov : P) {res : Resolved S Rev V W}
    (h : r.resolve c.source = .ok res) (h1 : c.ruleRevision = rest.ruleRevision) (h2 : c.source ≠ res.source) :
    ∃ m, admitResolved (P := P) r c rest recompute prov = .error (.mismatch m) ∧ m.stage = Stage.source := by
  obtain ⟨m, hm, hs⟩ := admit_source_first (P := P) (c := c) (e := res.expected rest) (recompute := recompute res.value) (prov := prov) h1 h2
  refine ⟨m, ?_, hs⟩
  unfold admitResolved
  rw [if_pos h1, h]
  simp only [hm]

/-- 受理された照合の証明書は入力の証明書であり、その入力参照は resolver の観測の参照に等しく、射影ダイジェストは観測した内容からの再計算に等しい -/
theorem admitResolved_source_eq {S Rev V W F C Obs R E P : Type} [DecidableEq S] [DecidableEq Rev] [DecidableEq C] [DecidableEq Obs] [DecidableEq R] [ToString S] [ToString Rev] [ToString C] [ToString Obs] [ToString R]
    (r : Resolver S Rev V W F) (c : Certificate S Rev C Obs R E) (rest : ExpectedRest C Obs R)
    (recompute : V → SourceRef S Rev → C → Obs → E → List ProjectionDigest) (prov : P) {k : ResolvedChecked S Rev V W C Obs R E}
    (h : admitResolved (P := P) r c rest recompute prov = .ok k) :
    r.resolve c.source = .ok k.resolved ∧ k.checked.input = c ∧ c.source = k.resolved.source ∧
      c.digests = recompute k.resolved.value c.source c.coordinate c.observations c.evidence := by
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
        obtain ⟨hi, he, hr', _⟩ := admit_sound hc
        have hsrc := k'.source_eq
        have hdig := k'.digests_eq
        rw [hi, he] at hsrc
        rw [hi, hr'] at hdig
        exact ⟨rfl, hi, hsrc, hdig⟩
  · cases h

end NecoQuotient
