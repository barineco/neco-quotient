import gleam/dict.{type Dict}
import gleam/list
import gleam/set

pub type DigestScope {
  WithinRuntime(payload: String)
  CrossLanguage(payload: String)
}

pub type ProjectionDigest {
  ProjectionDigest(digest: String, scope: DigestScope)
}

pub type ProjectionDigests =
  Dict(String, ProjectionDigest)

pub type ProjectionResult {
  Matched(value: ProjectionDigest)
  CertificateOnly(actual: ProjectionDigest)
  RecomputedOnly(expected: ProjectionDigest)
  Different(expected: ProjectionDigest, actual: ProjectionDigest)
}

pub type DigestChecks =
  Dict(String, ProjectionResult)

pub fn check(
  expected: ProjectionDigests,
  actual: ProjectionDigests,
) -> DigestChecks {
  let names =
    set.union(
      set.from_list(dict.keys(expected)),
      set.from_list(dict.keys(actual)),
    )
  set.fold(names, dict.new(), fn(checks, name) {
    case dict.get(expected, name), dict.get(actual, name) {
      Ok(recomputed), Ok(certificate) ->
        dict.insert(checks, name, both(recomputed, certificate))
      Ok(recomputed), Error(Nil) ->
        dict.insert(checks, name, RecomputedOnly(recomputed))
      Error(Nil), Ok(certificate) ->
        dict.insert(checks, name, CertificateOnly(certificate))
      Error(Nil), Error(Nil) -> checks
    }
  })
}

pub fn is_matched(result: ProjectionResult) -> Bool {
  case result {
    Matched(_) -> True
    _ -> False
  }
}

pub fn all_matched(checks: DigestChecks) -> Bool {
  dict.values(checks) |> list.all(is_matched)
}

fn both(
  expected: ProjectionDigest,
  actual: ProjectionDigest,
) -> ProjectionResult {
  case expected == actual {
    True -> Matched(expected)
    False -> Different(expected:, actual:)
  }
}
