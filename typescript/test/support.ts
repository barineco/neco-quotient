import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import type {
  Certificate,
  Comparison,
  DigestScope,
  Expected,
  ProjectionDigest,
  Rule,
  RuleEntry,
  SourceRef,
} from "../src/index.ts";
import { residualSet } from "../src/index.ts";

export const CASES_URL = new URL("../../comparison/certificate-admit/cases.json", import.meta.url);
export const OUTCOMES_URL = new URL(
  "../../comparison/certificate-admit/lean-outcomes.json",
  import.meta.url,
);
export const RESIDUAL_SET_API_CASES_URL = new URL(
  "../../comparison/certificate-admit/residual-set-api-cases-v1.json",
  import.meta.url,
);
export const RESIDUAL_SET_API_OUTCOMES_URL = new URL(
  "../../comparison/certificate-admit/residual-set-api-outcomes-v1.json",
  import.meta.url,
);

export const COMPARISON_REVISION = "comparison/sha256@1";

export function sha256Hex(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex");
}

export function canonicalString(text: string): string {
  let out = '"';
  for (const character of text) {
    const code = character.charCodeAt(0);
    switch (character) {
      case '"':
        out += '\\"';
        break;
      case "\\":
        out += "\\\\";
        break;
      case "\b":
        out += "\\b";
        break;
      case "\f":
        out += "\\f";
        break;
      case "\n":
        out += "\\n";
        break;
      case "\r":
        out += "\\r";
        break;
      case "\t":
        out += "\\t";
        break;
      default:
        out += code < 0x20 ? `\\u${code.toString(16).padStart(4, "0")}` : character;
    }
  }
  return `${out}"`;
}

export const evidenceRule: Rule<string, string, string, string, string> = (
  _source,
  _coordinate,
  _observations,
  evidence,
) => [
  {
    projection: "evidence",
    digest: sha256Hex(new TextEncoder().encode(canonicalString(evidence))),
    scope: { kind: "cross_language", encoding: "sha256" },
  },
];

export const stringComparison: Comparison<string, string, string, string, string> = {
  sameSource: (left, right) => left === right,
  sameRevision: (left, right) => left === right,
  sameCoordinate: (left, right) => left === right,
  sameObservations: (left, right) => left === right,
  sameResidual: (left, right) => left === right,
  identityText: (identity) => identity,
  revisionText: (revision) => revision,
};

export function comparisonEntries(): RuleEntry<string, string, string, string, string>[] {
  return [[COMPARISON_REVISION, evidenceRule]];
}

type WireScope = { readonly cross_language: string } | { readonly within_runtime: string };

export function scopeFromWire(scope: WireScope): DigestScope {
  if ("cross_language" in scope) {
    return { kind: "cross_language", encoding: scope.cross_language };
  }
  return { kind: "within_runtime", runtime: scope.within_runtime };
}

type WireDigest = { readonly projection: string; readonly digest: string; readonly scope: WireScope };

export function digestFromWire(digest: WireDigest): ProjectionDigest {
  return {
    projection: digest.projection,
    digest: digest.digest,
    scope: scopeFromWire(digest.scope),
  };
}

type WireSource = { readonly identity: string; readonly revision: string };

function sourceFromWire(source: WireSource): SourceRef<string, string> {
  return { identity: source.identity, revision: source.revision };
}

export type WireCertificate = {
  readonly rule_revision: string;
  readonly source: WireSource;
  readonly coordinate: string;
  readonly digests: readonly WireDigest[];
  readonly residuals: readonly string[];
  readonly observations: string;
  readonly evidence: string;
};

export type WireExpected = {
  readonly rule_revision: string;
  readonly source: WireSource;
  readonly coordinate: string;
  readonly observations: string;
  readonly residuals: readonly string[];
};

export function certificateFromWire(
  wire: WireCertificate,
): Certificate<string, string, string, string, string, string> {
  return {
    ruleRevision: wire.rule_revision,
    source: sourceFromWire(wire.source),
    coordinate: wire.coordinate,
    digests: wire.digests.map(digestFromWire),
    residuals: residualSet(wire.residuals),
    observations: wire.observations,
    evidence: wire.evidence,
  };
}

export function expectedFromWire(wire: WireExpected): Expected<string, string, string, string, string> {
  return {
    ruleRevision: wire.rule_revision,
    source: sourceFromWire(wire.source),
    coordinate: wire.coordinate,
    observations: wire.observations,
    residuals: residualSet(wire.residuals),
  };
}

export type CaseRow = {
  readonly name: string;
  readonly certificate: WireCertificate;
  readonly expected: WireExpected;
  readonly provenance: string;
};

export type OutcomeRow = {
  readonly name: string;
  readonly accepted: boolean;
  readonly residuals: readonly string[];
  readonly failure?: {
    readonly operation: string;
    readonly stage: string;
    readonly origin: {
      readonly rule_revision: string;
      readonly source_identity: string;
      readonly source_revision: string;
    };
  };
};

export function readJson<T>(url: URL): T {
  return JSON.parse(readFileSync(url, "utf8")) as T;
}
