import Lean.Data.Json
import NecoQuotient

set_option autoImplicit false

namespace NecoQuotient.Comparison.Cases

open Lean
open NecoQuotient

structure Case where
  name : String
  certificate : Certificate String String String String String String
  expected : Expected String String String String String
  provenance : String

def strField (object : Json) (key : String) : Except String String := do
  let value ← object.getObjVal? key
  value.getStr?

def objField (object : Json) (key : String) : Except String Json :=
  object.getObjVal? key

def listField (object : Json) (key : String) : Except String (List Json) := do
  let value ← object.getObjVal? key
  let items ← value.getArr?
  return items.toList

def sourceOf (object : Json) : Except String (SourceRef String String) := do
  let identity ← strField object "identity"
  let revision ← strField object "revision"
  return { identity := identity, revision := revision }

def scopeOf (object : Json) : Except String DigestScope := do
  match object.getObjVal? "cross_language" with
  | .ok value =>
    let name ← value.getStr?
    return .crossLanguage name
  | .error _ =>
    let value ← object.getObjVal? "within_runtime"
    let name ← value.getStr?
    return .withinRuntime name

def digestOf (object : Json) : Except String ProjectionDigest := do
  let digest ← strField object "digest"
  let scope ← scopeOf (← objField object "scope")
  return { digest := digest, scope := scope }

def digestsOf (object : Json) : Except String ProjectionDigests := do
  let entries ← object.getObj?
  let digests ← entries.toList.mapM (fun (name, value) => do
    let digest ← digestOf value
    return (name, digest))
  match NameMap.ofList digests with
  | some map => return map
  | none => throw "duplicate projection name"

def certificateOf (object : Json) : Except String (Certificate String String String String String String) := do
  let ruleRevision ← strField object "rule_revision"
  let source ← sourceOf (← objField object "source")
  let coordinate ← strField object "coordinate"
  let digests ← digestsOf (← objField object "digests")
  let residuals ← (← listField object "residuals").mapM (fun item => item.getStr?)
  let observations ← strField object "observations"
  let evidence ← strField object "evidence"
  return { ruleRevision := ruleRevision, source := source, coordinate := coordinate, digests := digests, residuals := ResidualSet.ofList residuals, observations := observations, evidence := evidence }

def expectedOf (object : Json) : Except String (Expected String String String String String) := do
  let ruleRevision ← strField object "rule_revision"
  let source ← sourceOf (← objField object "source")
  let coordinate ← strField object "coordinate"
  let observations ← strField object "observations"
  let residuals ← (← listField object "residuals").mapM (fun item => item.getStr?)
  return { ruleRevision := ruleRevision, source := source, coordinate := coordinate, observations := observations, residuals := ResidualSet.ofList residuals }

def caseOf (object : Json) : Except String Case := do
  let name ← strField object "name"
  let certificate ← certificateOf (← objField object "certificate")
  let expected ← expectedOf (← objField object "expected")
  let provenance ← strField object "provenance"
  return { name := name, certificate := certificate, expected := expected, provenance := provenance }

def load (text : String) : Except String (List Case) := do
  let root ← Json.parse text
  let rows ← root.getArr?
  rows.toList.mapM caseOf

end NecoQuotient.Comparison.Cases
