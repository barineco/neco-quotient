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
  { input := _, expected := _, recomputed := _, ruleRevision_eq := _, source_eq := _, coordinate_eq := _, observations_eq := _, digests_eq := _, residuals_match := _, residuals_match_eq := _ }

end NecoQuotient
