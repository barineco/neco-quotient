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

def comparisonRevision : String := "comparison/sha256@1"

def evidenceRecompute : Recompute String String String String String :=
  fun _ _ _ evidence =>
    ((NameMap.empty : ProjectionDigests).addNew "evidence"
      { digest := Digest.toHex (Digest.sha256 (stringText evidence).toUTF8)
        scope := .crossLanguage "sha256" })

def comparisonTable : RuleTable String String String String String :=
  [(comparisonRevision, { recompute := evidenceRecompute })]

def admitCase (item : Case) : Except (Mismatch String) (Checked String String String String String String) :=
  admitWithRules comparisonTable item.certificate item.expected item.provenance

open Lean in
def scopeJson : DigestScope → Json
  | .withinRuntime runtime => Json.mkObj [("within_runtime", Json.str runtime)]
  | .crossLanguage encoding => Json.mkObj [("cross_language", Json.str encoding)]

open Lean in
def digestJson (digest : ProjectionDigest) : Json :=
  Json.mkObj [("digest", Json.str digest.digest), ("scope", scopeJson digest.scope)]

open Lean in
def projectionJson : ProjectionResult → Json
  | .matched value => Json.mkObj [("result", Json.str "matched"), ("value", digestJson value)]
  | .certificateOnly actual => Json.mkObj [("result", Json.str "certificate_only"), ("actual", digestJson actual)]
  | .recomputedOnly expected => Json.mkObj [("result", Json.str "recomputed_only"), ("expected", digestJson expected)]
  | .different expected actual =>
    Json.mkObj [("result", Json.str "different"), ("expected", digestJson expected), ("actual", digestJson actual)]

open Lean in
def failureJson {stage : Stage} (failure : ConditionFailure stage String) : Json :=
  Json.mkObj [
    ("operation", Json.str failure.operation),
    ("origin", Json.mkObj [
      ("rule_revision", Json.str failure.origin.ruleRevision),
      ("source_identity", Json.str failure.origin.sourceIdentity),
      ("source_revision", Json.str failure.origin.sourceRevision)])]

open Lean in
def matchedJson : Json := Json.mkObj [("status", Json.str "matched")]

open Lean in
def mismatchedJson {stage : Stage} (failure : ConditionFailure stage String) : Json :=
  Json.mkObj [("status", Json.str "mismatched"), ("failure", failureJson failure)]

open Lean in
def uncheckedJson {stage : Stage} (prerequisite : String) (failure : ConditionFailure stage String) : Json :=
  Json.mkObj [("status", Json.str "unchecked"), ("prerequisite", Json.str prerequisite), ("failure", failureJson failure)]

open Lean in
def resultJson {stage : Stage} : CheckResult (ConditionFailure stage String) → Json
  | .matched => matchedJson
  | .mismatched failure => mismatchedJson failure

open Lean in
def childJson {stage : Stage} (checks : AdmissionChecks String)
    (select : SourceChecks String → CheckResult (ConditionFailure stage String)) : Json :=
  match checks.source with
  | .failed failure => uncheckedJson "source" failure
  | .established children => resultJson (select children)

open Lean in
def digestConditionJson (checks : AdmissionChecks String) : Json :=
  match checks.decode with
  | .failed failure => uncheckedJson "decode" failure
  | .established results =>
    Json.mkObj [
      ("status", Json.str (if results.allMatched then "matched" else "mismatched")),
      ("projections", Json.mkObj (results.entries.map (fun entry => (entry.1, projectionJson entry.2))))]

open Lean in
def conditionsJson (checks : AdmissionChecks String) : Json :=
  Json.mkObj [
    ("decode", match checks.decode with
      | .failed failure => mismatchedJson failure
      | .established _ => matchedJson),
    ("source", match checks.source with
      | .failed failure => mismatchedJson failure
      | .established _ => matchedJson),
    ("digest", digestConditionJson checks),
    ("coordinate", childJson checks (·.coordinate)),
    ("observations", childJson checks (·.observations)),
    ("residual", childJson checks (·.residual))]

def outcomeOf (item : Case) : Lean.Json :=
  let residuals :=
    (List.mergeSort item.certificate.residuals.values (fun left right => decide (left <= right))).toArray.map Lean.Json.str
  let (accepted, checks) :=
    match admitCase item with
    | .ok _ =>
      (true, checksOf item.certificate item.expected (selectWithRules comparisonTable item.certificate item.expected item.provenance) item.provenance)
    | .error mismatch => (false, mismatch.checks)
  Lean.Json.mkObj [("name", Lean.Json.str item.name), ("accepted", Lean.Json.bool accepted),
    ("conditions", conditionsJson checks), ("residuals", Lean.Json.arr residuals)]

end NecoQuotient.Comparison.Admission
