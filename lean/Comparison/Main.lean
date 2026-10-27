import Lean.Data.Json
import Comparison.Admission
import Comparison.Cases

/-- 事例の JSON を読み、実際の照合の結果を標準の JSON の正規の表記で書く -/
def main (args : List String) : IO UInt32 := do
  match args with
  | [casesPath, outcomesPath] =>
    let text ← IO.FS.readFile casesPath
    match NecoQuotient.Comparison.Cases.load text with
    | .error message =>
      IO.eprintln s!"cases: {message}"
      return 1
    | .ok items =>
      let outcomes := items.map NecoQuotient.Comparison.Admission.outcomeOf
      IO.FS.writeFile outcomesPath (Lean.Json.arr outcomes.toArray).compress
      return 0
  | _ =>
    IO.eprintln "usage: certificate_compare <cases.json> <lean-outcomes.json>"
    return 2
