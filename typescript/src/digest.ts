export type DigestScope =
  | { readonly kind: "within_runtime"; readonly runtime: string }
  | { readonly kind: "cross_language"; readonly encoding: string };

export type ProjectionDigest = {
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
  return left.digest === right.digest && sameDigestScope(left.scope, right.scope);
}

function freezeDigestScope(scope: DigestScope): DigestScope {
  switch (scope.kind) {
    case "within_runtime":
      return Object.freeze({ kind: "within_runtime", runtime: scope.runtime });
    case "cross_language":
      return Object.freeze({ kind: "cross_language", encoding: scope.encoding });
  }
}

export function freezeProjectionDigest(digest: ProjectionDigest): ProjectionDigest {
  return Object.freeze({ digest: digest.digest, scope: freezeDigestScope(digest.scope) });
}

export function compareUtf8(left: string, right: string): number {
  const leftPoints = Array.from(left, (character) => character.codePointAt(0) ?? 0);
  const rightPoints = Array.from(right, (character) => character.codePointAt(0) ?? 0);
  const length = Math.min(leftPoints.length, rightPoints.length);
  for (let index = 0; index < length; index += 1) {
    const difference = (leftPoints[index] ?? 0) - (rightPoints[index] ?? 0);
    if (difference !== 0) return difference < 0 ? -1 : 1;
  }
  return Math.sign(leftPoints.length - rightPoints.length);
}

export type NameMapInput<V> = ReadonlyMap<string, V> | Readonly<Record<string, V>> | NameMap<V>;

function entriesOf<V>(input: NameMapInput<V>): readonly (readonly [string, V])[] {
  if (input instanceof NameMap) return input.entries();
  if (input instanceof Map) return [...input.entries()];
  const prototype: unknown = Object.getPrototypeOf(input);
  if (prototype !== Object.prototype && prototype !== null) {
    throw new TypeError("a name map is built from a Map, a NameMap or a plain record");
  }
  return Object.entries(input);
}

export class NameMap<V> {
  readonly #entries: ReadonlyMap<string, V>;

  private constructor(entries: ReadonlyMap<string, V>) {
    this.#entries = entries;
    Object.freeze(this);
  }

  static copyOf<V>(input: NameMapInput<V>, copyValue: (value: V) => V): NameMap<V> {
    const copied = new Map<string, V>();
    for (const [name, value] of entriesOf(input)) {
      copied.set(name, copyValue(value));
    }
    return new NameMap(copied);
  }

  get size(): number {
    return this.#entries.size;
  }

  has(name: string): boolean {
    return this.#entries.has(name);
  }

  get(name: string): V | undefined {
    return this.#entries.get(name);
  }

  names(): readonly string[] {
    return Object.freeze([...this.#entries.keys()].sort(compareUtf8));
  }

  entries(): readonly (readonly [string, V])[] {
    const sorted = [...this.#entries.entries()].sort(([left], [right]) => compareUtf8(left, right));
    return Object.freeze(sorted.map((entry) => Object.freeze([entry[0], entry[1]] as const)));
  }

  values(): readonly V[] {
    return Object.freeze(this.entries().map(([, value]) => value));
  }

  [Symbol.iterator](): IterableIterator<readonly [string, V]> {
    return this.entries()[Symbol.iterator]();
  }
}

export type ProjectionDigests = NameMap<ProjectionDigest>;
export type ProjectionDigestsInput = NameMapInput<ProjectionDigest>;

export function projectionDigests(input: ProjectionDigestsInput): ProjectionDigests {
  return NameMap.copyOf(input, freezeProjectionDigest);
}
