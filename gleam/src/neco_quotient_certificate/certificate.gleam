import gleam/list
import neco_quotient_certificate/digest.{type ProjectionDigests}
import neco_quotient_certificate/source.{type SourceRef}

pub opaque type ResidualSet(r) {
  ResidualSet(values: List(r))
}

pub fn residual_set(values: List(r)) -> ResidualSet(r) {
  ResidualSet(list.unique(values))
}

pub fn residual_values(set: ResidualSet(r)) -> List(r) {
  let ResidualSet(values) = set
  values
}

pub fn same_residuals(left: ResidualSet(r), right: ResidualSet(r)) -> Bool {
  let left_values = residual_values(left)
  let right_values = residual_values(right)
  list.length(left_values) == list.length(right_values)
  && list.all(left_values, fn(value) { list.contains(right_values, value) })
}

pub type Certificate(s, rev, c, obs, r, e) {
  Certificate(
    rule_revision: String,
    source: SourceRef(s, rev),
    coordinate: c,
    digests: ProjectionDigests,
    residuals: ResidualSet(r),
    observations: obs,
    evidence: e,
  )
}

pub type Expected(s, rev, c, obs, r) {
  Expected(
    rule_revision: String,
    source: SourceRef(s, rev),
    coordinate: c,
    observations: obs,
    residuals: ResidualSet(r),
  )
}
