export type DigestScope =
  | { readonly kind: "within_runtime"; readonly runtime: string }
  | { readonly kind: "cross_language"; readonly encoding: string };

export type ProjectionDigest = {
  readonly projection: string;
  readonly digest: string;
  readonly scope: DigestScope;
};

export function sameDigestScope(left: DigestScope, right: DigestScope): boolean {
  switch (left.kind) {
    case "within_runtime":
      return right.kind === "within_runtime" && left.runtime === right.runtime;
    case "cross_language":
      return right.kind === "cross_language" && left.encoding === right.encoding;
  }
}

export function sameProjectionDigest(left: ProjectionDigest, right: ProjectionDigest): boolean {
  return (
    left.projection === right.projection &&
    left.digest === right.digest &&
    sameDigestScope(left.scope, right.scope)
  );
}

export function sameProjectionDigests(
  left: readonly ProjectionDigest[],
  right: readonly ProjectionDigest[],
): boolean {
  const rightItems = right[Symbol.iterator]();
  for (const item of left) {
    const next = rightItems.next();
    if (next.done === true || !sameProjectionDigest(item, next.value)) {
      return false;
    }
  }
  return rightItems.next().done === true;
}

function freezeDigestScope(scope: DigestScope): DigestScope {
  switch (scope.kind) {
    case "within_runtime":
      return Object.freeze({ kind: "within_runtime", runtime: scope.runtime });
    case "cross_language":
      return Object.freeze({ kind: "cross_language", encoding: scope.encoding });
  }
}

export function freezeProjectionDigests(
  digests: readonly ProjectionDigest[],
): readonly ProjectionDigest[] {
  return Object.freeze(
    digests.map((digest) =>
      Object.freeze({
        projection: digest.projection,
        digest: digest.digest,
        scope: freezeDigestScope(digest.scope),
      }),
    ),
  );
}
