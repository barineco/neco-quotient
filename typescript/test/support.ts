import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import type {
  AdmissionChecks,
  Certificate,
  CheckResult,
  Comparison,
  ConditionFailure,
  DigestScope,
  Expected,
  ProjectionDigest,
  ProjectionDigests,
  ProjectionResult,
  Rule,
  RuleEntry,
  SourceRef,
} from "../src/index.ts";
import { projectionDigests, residualSet } from "../src/index.ts";

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
) => ({
  evidence: {
    digest: sha256Hex(new TextEncoder().encode(canonicalString(evidence))),
    scope: { kind: "cross_language", encoding: "sha256" },
  },
});

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

type WireDigest = { readonly digest: string; readonly scope: WireScope };

export function digestFromWire(digest: WireDigest): ProjectionDigest {
  return { digest: digest.digest, scope: scopeFromWire(digest.scope) };
}

export function digestsFromWire(digests: Readonly<Record<string, WireDigest>>): ProjectionDigests {
  return projectionDigests(
    new Map(Object.entries(digests).map(([name, digest]) => [name, digestFromWire(digest)])),
  );
}

type WireSource = { readonly identity: string; readonly revision: string };

function sourceFromWire(source: WireSource): SourceRef<string, string> {
  return { identity: source.identity, revision: source.revision };
}

export type WireCertificate = {
  readonly rule_revision: string;
  readonly source: WireSource;
  readonly coordinate: string;
  readonly digests: Readonly<Record<string, WireDigest>>;
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
    digests: digestsFromWire(wire.digests),
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

export function readJson<T>(url: URL): T {
  return JSON.parse(readFileSync(url, "utf8")) as T;
}

export function readBytes(url: URL): Buffer {
  return readFileSync(url);
}

type Json = null | boolean | string | readonly Json[] | { readonly [key: string]: Json };

export function canonicalJson(value: Json): string {
  if (typeof value === "string") return canonicalString(value);
  if (value === null || typeof value === "boolean") return String(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  const object = value as { readonly [key: string]: Json };
  const keys = Object.keys(object).sort((left, right) =>
    Buffer.compare(Buffer.from(left, "utf8"), Buffer.from(right, "utf8")),
  );
  return `{${keys.map((key) => `${canonicalString(key)}:${canonicalJson(object[key] as Json)}`).join(",")}}`;
}

function scopeJson(scope: DigestScope): Json {
  return scope.kind === "cross_language"
    ? { cross_language: scope.encoding }
    : { within_runtime: scope.runtime };
}

function digestJson(digest: ProjectionDigest): Json {
  return { digest: digest.digest, scope: scopeJson(digest.scope) };
}

function projectionJson(result: ProjectionResult): Json {
  switch (result.kind) {
    case "matched":
      return { result: "matched", value: digestJson(result.value) };
    case "certificate_only":
      return { result: "certificate_only", actual: digestJson(result.actual) };
    case "recomputed_only":
      return { result: "recomputed_only", expected: digestJson(result.expected) };
    case "different":
      return {
        result: "different",
        expected: digestJson(result.expected),
        actual: digestJson(result.actual),
      };
  }
}

function failureJson(failure: ConditionFailure<never, unknown>): Json {
  return {
    operation: failure.operation,
    origin: {
      rule_revision: failure.origin.ruleRevision,
      source_identity: failure.origin.sourceIdentity,
      source_revision: failure.origin.sourceRevision,
    },
  };
}

function uncheckedJson(prerequisite: string, failure: ConditionFailure<never, unknown>): Json {
  return { status: "unchecked", prerequisite, failure: failureJson(failure) };
}

function checkJson(result: CheckResult<ConditionFailure<never, unknown>>): Json {
  return result.kind === "matched"
    ? { status: "matched" }
    : { status: "mismatched", failure: failureJson(result.failure) };
}

export function conditionsJson(checks: AdmissionChecks<unknown>): Json {
  const sourceChild = (
    select: (children: Extract<typeof checks.source, { kind: "established" }>["children"]) => CheckResult<ConditionFailure<never, unknown>>,
  ): Json =>
    checks.source.kind === "failed"
      ? uncheckedJson("source", checks.source.failure)
      : checkJson(select(checks.source.children));
  let digest: Json;
  if (checks.decode.kind === "failed") {
    digest = uncheckedJson("decode", checks.decode.failure);
  } else {
    const projections: { [name: string]: Json } = {};
    for (const [name, result] of checks.decode.children.entries()) {
      projections[name] = projectionJson(result);
    }
    digest = {
      status: checks.statusAt("digest").kind,
      projections,
    };
  }
  return {
    decode:
      checks.decode.kind === "failed"
        ? { status: "mismatched", failure: failureJson(checks.decode.failure) }
        : { status: "matched" },
    source:
      checks.source.kind === "failed"
        ? { status: "mismatched", failure: failureJson(checks.source.failure) }
        : { status: "matched" },
    digest,
    coordinate: sourceChild((children) => children.coordinate),
    observations: sourceChild((children) => children.observations),
    residual: sourceChild((children) => children.residual),
  };
}

export function outcomeJson(
  name: string,
  accepted: boolean,
  checks: AdmissionChecks<unknown>,
  residuals: readonly string[],
): Json {
  return {
    accepted,
    conditions: conditionsJson(checks),
    name,
    residuals: [...residuals].sort(),
  };
}
