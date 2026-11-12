import NecoQuotient.Certificate

namespace NecoQuotient

/-- error: Unknown constant `NecoQuotient.Checked.mk` -/
#guard_msgs in
#check @Checked.mk

/-- error: Invalid `⟨...⟩` notation: Constructor for `NecoQuotient.Checked` is marked as private -/
#guard_msgs in
example : Checked String String String String String String := ⟨_, _, _, _, _, _, _, _, _⟩

/-- error: invalid {...} notation, constructor for `Checked` is marked as private -/
#guard_msgs in
example : Checked String String String String String String :=
  { input := _, expected := _, recomputed := _, ruleRevision_eq := _, source_eq := _, coordinate_eq := _, observations_eq := _, digests_eq := _, residuals_same := _ }

/-- error: Unknown constant `NecoQuotient.Mismatch.mk` -/
#guard_msgs in
#check @Mismatch.mk

/-- error: Invalid `⟨...⟩` notation: Constructor for `NecoQuotient.Mismatch` is marked as private -/
#guard_msgs in
example : Mismatch String := ⟨_, _⟩

private def sample : Certificate String String String String String String :=
  { ruleRevision := "r1", source := { identity := "s", revision := "1" }, coordinate := "x", digests := NameMap.empty,
    residuals := ResidualSet.ofList [], observations := "o", evidence := "" }

private def sampleExpected : Expected String String String String String :=
  { ruleRevision := "r1", source := { identity := "t", revision := "1" }, coordinate := "y", observations := "o",
    residuals := ResidualSet.ofList [] }

private def sampleStatus (condition : Condition) : Bool :=
  match admit (P := String) sample sampleExpected (fun _ _ _ _ => NameMap.empty) "caller" with
  | .error m =>
    match m.statusAt condition with
    | .uncheckedBySource _ => true
    | _ => false
  | .ok _ => false

#guard sampleStatus .coordinate && sampleStatus .observations && sampleStatus .residual
#guard !sampleStatus .digest

end NecoQuotient
