import neco_quotient_certificate/certificate.{residual_set, residual_values}
import neco_quotient_certificate/refinement.{
  type RefinementOutcome, Residual, Resolved, Stopped, same_outcome,
}

pub fn run() {
  three_cases_hold_their_parts()
  equal_cases_with_equal_parts_are_the_same()
  residual_order_and_duplicates_do_not_change_sameness()
  different_residual_members_are_not_the_same()
  different_value_or_cause_is_not_the_same()
  different_cases_are_not_the_same()
}

fn check(condition: Bool, message: String) {
  case condition {
    True -> Nil
    False -> panic as message
  }
}

fn residual(values: List(String)) -> RefinementOutcome(String, String, String) {
  Residual(value: "value", residuals: residual_set(values))
}

fn stopped(
  values: List(String),
  cause: String,
) -> RefinementOutcome(String, String, String) {
  Stopped(value: "value", residuals: residual_set(values), cause: cause)
}

fn resolved() -> RefinementOutcome(String, String, String) {
  Resolved("value")
}

fn three_cases_hold_their_parts() {
  let assert Resolved(value) = resolved()
  check(value == "value", "resolved keeps its value")
  let assert Residual(value, residuals) = residual(["residual-a", "residual-b"])
  check(value == "value", "residual keeps its value")
  check(
    residual_values(residuals) == ["residual-a", "residual-b"],
    "residual keeps its residuals",
  )
  let assert Stopped(value, residuals, cause) =
    stopped(["residual-a"], "budget")
  check(value == "value", "stopped keeps its value")
  check(residual_values(residuals) == ["residual-a"], "stopped keeps residuals")
  check(cause == "budget", "stopped keeps its cause")
}

fn equal_cases_with_equal_parts_are_the_same() {
  check(same_outcome(resolved(), resolved()), "resolved")
  check(
    same_outcome(residual(["residual-a"]), residual(["residual-a"])),
    "residual",
  )
  check(
    same_outcome(
      stopped(["residual-a"], "budget"),
      stopped(["residual-a"], "budget"),
    ),
    "stopped",
  )
}

fn residual_order_and_duplicates_do_not_change_sameness() {
  check(
    same_outcome(
      residual(["residual-b", "residual-a", "residual-a"]),
      residual(["residual-a", "residual-b"]),
    ),
    "residual order and duplicates",
  )
  check(
    same_outcome(
      stopped(["residual-b", "residual-a"], "budget"),
      stopped(["residual-a", "residual-b"], "budget"),
    ),
    "stopped residual order",
  )
}

fn different_residual_members_are_not_the_same() {
  check(
    !same_outcome(
      residual(["residual-a", "residual-b"]),
      residual(["residual-a", "residual-c"]),
    ),
    "different member",
  )
  check(
    !same_outcome(
      residual(["residual-a"]),
      residual(["residual-a", "residual-b"]),
    ),
    "extra member",
  )
}

fn different_value_or_cause_is_not_the_same() {
  check(!same_outcome(Resolved("value"), Resolved("other")), "resolved value")
  check(
    !same_outcome(
      residual(["residual-a"]),
      Residual("other", residual_set(["residual-a"])),
    ),
    "residual value",
  )
  check(
    !same_outcome(
      stopped(["residual-a"], "budget"),
      stopped(["residual-a"], "timeout"),
    ),
    "stopped cause",
  )
}

fn different_cases_are_not_the_same() {
  check(
    !same_outcome(resolved(), residual(["residual-a"])),
    "resolved residual",
  )
  check(
    !same_outcome(residual(["residual-a"]), stopped(["residual-a"], "budget")),
    "residual stopped",
  )
  check(!same_outcome(resolved(), stopped([], "budget")), "resolved stopped")
  check(!same_outcome(stopped([], "budget"), resolved()), "stopped resolved")
  check(!same_outcome(residual([]), resolved()), "empty residual resolved")
}
