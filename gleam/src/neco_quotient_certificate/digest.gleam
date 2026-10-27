/// 射影ダイジェストの比較範囲。payload は実行環境または比較規約の名前。
pub type DigestScope {
  WithinRuntime(payload: String)
  CrossLanguage(payload: String)
}

/// 入力の一つの射影ダイジェスト。
pub type ProjectionDigest {
  ProjectionDigest(projection: String, digest: String, scope: DigestScope)
}
