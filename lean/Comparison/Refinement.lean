import Lean.Data.Json
import NecoQuotient

set_option autoImplicit false

namespace NecoQuotient.Comparison.Refinement

open Lean
open NecoQuotient

abbrev Result := RefinementResult String String String

structure Case where
  name : String
  left : Result
  right : Result

def strField (object : Json) (key : String) : Except String String := do
  let value ← object.getObjVal? key
  value.getStr?

def residualsField (object : Json) : Except String (ResidualSet String) := do
  let value ← object.getObjVal? "residuals"
  let items ← value.getArr?
  let values ← items.toList.mapM (fun item => item.getStr?)
  return ResidualSet.ofList values

def resultOf (object : Json) : Except String Result := do
  let kind ← strField object "kind"
  let value ← strField object "value"
  match kind with
  | "resolved" => return { evaluation := value, status := .resolved }
  | "residual" =>
    let residuals ← residualsField object
    return { evaluation := value, status := .residual residuals }
  | "stopped" =>
    let residuals ← residualsField object
    let cause ← strField object "cause"
    return { evaluation := value, status := .stopped residuals cause }
  | _ => throw s!"unknown kind {kind}"

def caseOf (object : Json) : Except String Case := do
  let name ← strField object "name"
  let left ← resultOf (← object.getObjVal? "left")
  let right ← resultOf (← object.getObjVal? "right")
  return { name := name, left := left, right := right }

def load (text : String) : Except String (List Case) := do
  let root ← Json.parse text
  let rows ← root.getArr?
  rows.toList.mapM caseOf

def sameStatus : RefinementStatus String String → RefinementStatus String String → Bool
  | .resolved, .resolved => true
  | .residual left, .residual right => ResidualSet.same left right
  | .stopped leftResiduals leftCause, .stopped rightResiduals rightCause =>
    ResidualSet.same leftResiduals rightResiduals && leftCause == rightCause
  | _, _ => false

def sameResult (left right : Result) : Bool :=
  left.evaluation == right.evaluation && sameStatus left.status right.status

def sortedJson (residuals : ResidualSet String) : Json :=
  Json.arr
    ((List.mergeSort residuals.values (fun left right => decide (left <= right))).toArray.map Json.str)

def resultJson (result : Result) : Json :=
  match result.status with
  | .resolved => Json.mkObj [("kind", Json.str "resolved"), ("value", Json.str result.evaluation)]
  | .residual residuals =>
    Json.mkObj [("kind", Json.str "residual"), ("value", Json.str result.evaluation),
      ("residuals", sortedJson residuals)]
  | .stopped residuals cause =>
    Json.mkObj [("kind", Json.str "stopped"), ("value", Json.str result.evaluation),
      ("residuals", sortedJson residuals), ("cause", Json.str cause)]

def outcomeOf (item : Case) : Json :=
  Json.mkObj [("name", Json.str item.name), ("left", resultJson item.left),
    ("right", resultJson item.right), ("same", Json.bool (sameResult item.left item.right))]

end NecoQuotient.Comparison.Refinement
