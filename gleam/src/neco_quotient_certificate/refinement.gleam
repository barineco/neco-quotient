import neco_quotient_certificate/certificate.{type ResidualSet, same_residuals}

pub type RefinementOutcome(v, r, s) {
  Resolved(value: v)
  Residual(value: v, residuals: ResidualSet(r))
  Stopped(value: v, residuals: ResidualSet(r), cause: s)
}

pub fn same_outcome(
  left: RefinementOutcome(v, r, s),
  right: RefinementOutcome(v, r, s),
) -> Bool {
  case left, right {
    Resolved(left_value), Resolved(right_value) -> left_value == right_value
    Residual(left_value, left_residuals), Residual(right_value, right_residuals)
    ->
      left_value == right_value
      && same_residuals(left_residuals, right_residuals)
    Stopped(left_value, left_residuals, left_cause),
      Stopped(right_value, right_residuals, right_cause)
    ->
      left_value == right_value
      && same_residuals(left_residuals, right_residuals)
      && left_cause == right_cause
    _, _ -> False
  }
}
