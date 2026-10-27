import gleam/list
import neco_quotient_certificate/digest.{type ProjectionDigest}
import neco_quotient_certificate/source.{type SourceRef}

/// 要素の所属で同一性を決める残余集合。
pub opaque type ResidualSet(r) {
  ResidualSet(values: List(r))
}

/// 重複を除いた残余集合を作る。
pub fn residual_set(values: List(r)) -> ResidualSet(r) {
  ResidualSet(list.unique(values))
}

/// 残余集合の要素を構築時の順で返す。
pub fn residual_values(set: ResidualSet(r)) -> List(r) {
  let ResidualSet(values) = set
  values
}

/// 二つの残余集合が同じ要素所属を持つか返す。
pub fn same_residuals(left: ResidualSet(r), right: ResidualSet(r)) -> Bool {
  let left_values = residual_values(left)
  let right_values = residual_values(right)
  list.length(left_values) == list.length(right_values)
  && list.all(left_values, fn(value) { list.contains(right_values, value) })
}

/// 照合に提出する証明書。
pub type Certificate(s, rev, c, obs, r, e) {
  Certificate(
    rule_revision: String,
    source: SourceRef(s, rev),
    coordinate: c,
    digests: List(ProjectionDigest),
    residuals: ResidualSet(r),
    observations: obs,
    evidence: e,
  )
}

/// 証明書を照合する期待値。
pub type Expected(s, rev, c, obs, r) {
  Expected(
    rule_revision: String,
    source: SourceRef(s, rev),
    coordinate: c,
    observations: obs,
    residuals: ResidualSet(r),
  )
}
