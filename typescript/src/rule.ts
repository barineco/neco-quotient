import type { SourceRef } from "./certificate.ts";
import type { ProjectionDigest } from "./digest.ts";
import type { Result } from "./result.ts";

export type Rule<S, Rev, C, Obs, E> = (
  source: SourceRef<S, Rev>,
  coordinate: C,
  observations: Obs,
  evidence: E,
) => readonly ProjectionDigest[];

export type RuleEntry<S, Rev, C, Obs, E> = readonly [string, Rule<S, Rev, C, Obs, E>];

export type DuplicateRule = {
  readonly ruleRevision: string;
};

export class RuleTable<S, Rev, C, Obs, E> {
  readonly #entries: readonly RuleEntry<S, Rev, C, Obs, E>[];

  private constructor(entries: readonly RuleEntry<S, Rev, C, Obs, E>[]) {
    this.#entries = entries;
  }

  static create<S, Rev, C, Obs, E>(
    entries: readonly RuleEntry<S, Rev, C, Obs, E>[],
  ): Result<RuleTable<S, Rev, C, Obs, E>, DuplicateRule> {
    const seen = new Set<string>();
    for (const [ruleRevision] of entries) {
      if (seen.has(ruleRevision)) {
        return { ok: false, error: { ruleRevision } };
      }
      seen.add(ruleRevision);
    }
    const copied = entries.map(([ruleRevision, rule]) =>
      Object.freeze([ruleRevision, rule] as const),
    );
    return { ok: true, value: new RuleTable(Object.freeze(copied)) };
  }

  lookup(ruleRevision: string): Rule<S, Rev, C, Obs, E> | undefined {
    const entry = this.#entries.find(([revision]) => revision === ruleRevision);
    return entry?.[1];
  }
}
