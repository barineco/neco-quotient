import Lean.Data.Json
import NecoQuotient
import Comparison.Canonical
import Comparison.Cases
import Comparison.Sha256

set_option autoImplicit false

namespace NecoQuotient.Comparison.Admission

open NecoQuotient
open NecoQuotient.Comparison.Canonical
open NecoQuotient.Comparison.Cases

/-- 比較用の規則のリビジョン -/
def comparisonRevision : String := "comparison/sha256@1"

/-- 証明書の出所と呼出側の来歴 -/
structure Provenance where
  caller : String
  ruleRevision : String
  sourceIdentity : String
  sourceRevision : String

/-- 証拠の正規 JSON のバイト列の SHA-256 を、射影 evidence のダイジェストとして返す -/
def evidenceRecompute : SourceRef String String → String → String → String → List ProjectionDigest :=
  fun _ _ _ evidence =>
    [{ projection := "evidence"
       digest := Digest.toHex (Digest.sha256 (stringText evidence).toUTF8)
       scope := .crossLanguage "sha256" }]

/-- 比較用の規則の表 -/
def comparisonTable : RuleTable String String String String String :=
  [(comparisonRevision, { recompute := evidenceRecompute })]

/-- 事例を実際の照合 admitWithRules へ渡す。来歴には証明書のリビジョンと入力参照を入れる -/
def admitCase (item : Case) : Except (Mismatch Provenance) (Checked String String String String String String) :=
  let provenance : Provenance :=
    { caller := item.provenance
      ruleRevision := item.certificate.ruleRevision
      sourceIdentity := item.certificate.source.identity
      sourceRevision := item.certificate.source.revision }
  admitWithRules comparisonTable item.certificate item.expected provenance

/-- 段階の名前 -/
def stageName : Stage → String
  | .decode => "decode"
  | .source => "source"
  | .coordinate => "coordinate"
  | .observations => "observations"
  | .digest => "digest"
  | .residual => "residual"

/-- 事例の結果の一行。失敗の origin は返った来歴から読む -/
def outcomeOf (item : Case) : Lean.Json :=
  let residuals :=
    (List.mergeSort item.certificate.residuals.values (fun left right => decide (left <= right))).toArray.map Lean.Json.str
  match admitCase item with
  | .ok _ =>
    Lean.Json.mkObj [("name", Lean.Json.str item.name), ("accepted", Lean.Json.bool true), ("residuals", Lean.Json.arr residuals)]
  | .error mismatch =>
    let origin := mismatch.provenance
    Lean.Json.mkObj [("name", Lean.Json.str item.name), ("accepted", Lean.Json.bool false),
      ("failure", Lean.Json.mkObj [
        ("operation", Lean.Json.str mismatch.operation),
        ("stage", Lean.Json.str (stageName mismatch.stage)),
        ("origin", Lean.Json.mkObj [
          ("rule_revision", Lean.Json.str origin.ruleRevision),
          ("source_identity", Lean.Json.str origin.sourceIdentity),
          ("source_revision", Lean.Json.str origin.sourceRevision)])]),
      ("residuals", Lean.Json.arr residuals)]

end NecoQuotient.Comparison.Admission
