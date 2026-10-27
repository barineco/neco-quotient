import type { DigestScope, ProjectionDigest } from "./digest.ts";

export function describeList(values: readonly unknown[]): string {
  return `[${values.map((value) => String(value)).join(", ")}]`;
}

function describeScope(scope: DigestScope): string {
  switch (scope.kind) {
    case "within_runtime":
      return `within_runtime:${scope.runtime}`;
    case "cross_language":
      return `cross_language:${scope.encoding}`;
  }
}

export function describeDigests(digests: readonly ProjectionDigest[]): string {
  const items = digests.map(
    (digest) =>
      `{projection: ${digest.projection}, digest: ${digest.digest}, scope: ${describeScope(digest.scope)}}`,
  );
  return `[${items.join(", ")}]`;
}
