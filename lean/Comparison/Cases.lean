import Lean.Data.Json
import NecoQuotient

set_option autoImplicit false

namespace NecoQuotient.Comparison.Cases

open Lean
open NecoQuotient

/-- 比較の事例の一行 -/
structure Case where
  name : String
  certificate : Certificate String String String String String String
  expected : Expected String String String String String
  provenance : String

/-- 文字列の欄を読む -/
def strField (object : Json) (key : String) : Except String String := do
  let value ← object.getObjVal? key
  value.getStr?

/-- 対象の欄を読む -/
def objField (object : Json) (key : String) : Except String Json :=
  object.getObjVal? key

/-- 配列の欄を読む -/
def listField (object : Json) (key : String) : Except String (List Json) := do
  let value ← object.getObjVal? key
  let items ← value.getArr?
  return items.toList

/-- 入力参照を読む -/
def sourceOf (object : Json) : Except String (SourceRef String String) := do
  let identity ← strField object "identity"
  let revision ← strField object "revision"
  return { identity := identity, revision := revision }

/-- 射影ダイジェストの比較範囲を読む -/
def scopeOf (object : Json) : Except String DigestScope := do
  match object.getObjVal? "cross_language" with
  | .ok value =>
    let name ← value.getStr?
    return .crossLanguage name
  | .error _ =>
    let value ← object.getObjVal? "within_runtime"
    let name ← value.getStr?
    return .withinRuntime name

/-- 射影ダイジェストを読む -/
def digestOf (object : Json) : Except String ProjectionDigest := do
  let projection ← strField object "projection"
  let digest ← strField object "digest"
  let scope ← scopeOf (← objField object "scope")
  return { projection := projection, digest := digest, scope := scope }

/-- 証明書を読む -/
def certificateOf (object : Json) : Except String (Certificate String String String String String String) := do
  let ruleRevision ← strField object "rule_revision"
  let source ← sourceOf (← objField object "source")
  let coordinate ← strField object "coordinate"
  let digests ← (← listField object "digests").mapM digestOf
  let residuals ← (← listField object "residuals").mapM (fun item => item.getStr?)
  let observations ← strField object "observations"
  let evidence ← strField object "evidence"
  return { ruleRevision := ruleRevision, source := source, coordinate := coordinate, digests := digests, residuals := ResidualSet.ofList residuals, observations := observations, evidence := evidence }

/-- 期待値を読む -/
def expectedOf (object : Json) : Except String (Expected String String String String String) := do
  let ruleRevision ← strField object "rule_revision"
  let source ← sourceOf (← objField object "source")
  let coordinate ← strField object "coordinate"
  let observations ← strField object "observations"
  let residuals ← (← listField object "residuals").mapM (fun item => item.getStr?)
  return { ruleRevision := ruleRevision, source := source, coordinate := coordinate, observations := observations, residuals := ResidualSet.ofList residuals }

/-- 事例の一行を読む -/
def caseOf (object : Json) : Except String Case := do
  let name ← strField object "name"
  let certificate ← certificateOf (← objField object "certificate")
  let expected ← expectedOf (← objField object "expected")
  let provenance ← strField object "provenance"
  return { name := name, certificate := certificate, expected := expected, provenance := provenance }

/-- 事例の全体を読む。根は配列とする -/
def load (text : String) : Except String (List Case) := do
  let root ← Json.parse text
  let rows ← root.getArr?
  rows.toList.mapM caseOf

end NecoQuotient.Comparison.Cases
