import hashlib
import json
import unittest

from neco_quotient_certificate import (
    Certificate,
    Checked,
    CheckMatched,
    CheckMismatched,
    Condition,
    CrossLanguage,
    Expected,
    Mismatch,
    PrerequisiteFailed,
    ProjectionCertificateOnly,
    ProjectionDifferent,
    ProjectionMatched,
    ProjectionRecomputedOnly,
    ProjectionDigest,
    RuleTable,
    SourceRef,
    WithinRuntime,
    admit,
    check,
)

from _support import COMPARISON_DIR, reference_write_string

REVISION = "comparison/sha256@1"

def canonical_string(text):
    return json.dumps(text, ensure_ascii=False).encode("utf-8")

def comparison_rule(source, coordinate, observations, evidence):
    digest = hashlib.sha256(canonical_string(evidence)).hexdigest()
    return {"evidence": ProjectionDigest(digest, CrossLanguage("sha256"))}

def canonical_object_bytes(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")

def scope_of(value):
    if set(value) == {"cross_language"}:
        return CrossLanguage(value["cross_language"])
    if set(value) == {"within_runtime"}:
        return WithinRuntime(value["within_runtime"])
    raise ValueError(f"unknown digest scope {value!r}")

def source_of(value):
    return SourceRef(value["identity"], value["revision"])

def certificate_of(row):
    wire = row["certificate"]
    return Certificate(
        rule_revision=wire["rule_revision"],
        source=source_of(wire["source"]),
        coordinate=wire["coordinate"],
        digests={
            name: ProjectionDigest(item["digest"], scope_of(item["scope"]))
            for name, item in wire["digests"].items()
        },
        residuals=tuple(wire["residuals"]),
        observations=wire["observations"],
        evidence=wire["evidence"],
    )

def expected_of(row):
    wire = row["expected"]
    return Expected(
        rule_revision=wire["rule_revision"],
        source=source_of(wire["source"]),
        coordinate=wire["coordinate"],
        observations=wire["observations"],
        residuals=tuple(wire["residuals"]),
    )

def digest_json(digest):
    scope = digest.scope
    if isinstance(scope, CrossLanguage):
        scope_wire = {"cross_language": scope.name}
    else:
        scope_wire = {"within_runtime": scope.name}
    return {"digest": digest.digest, "scope": scope_wire}

def projection_json(result):
    if isinstance(result, ProjectionMatched):
        return {"result": "matched", "value": digest_json(result.value)}
    if isinstance(result, ProjectionCertificateOnly):
        return {"result": "certificate_only", "actual": digest_json(result.actual)}
    if isinstance(result, ProjectionRecomputedOnly):
        return {"result": "recomputed_only", "expected": digest_json(result.expected)}
    assert isinstance(result, ProjectionDifferent)
    return {
        "result": "different",
        "expected": digest_json(result.expected),
        "actual": digest_json(result.actual),
    }

def origin_json(origin):
    return {
        "rule_revision": origin.rule_revision,
        "source_identity": origin.source_identity,
        "source_revision": origin.source_revision,
    }

def failure_json(failure):
    return {"operation": failure.operation, "origin": origin_json(failure.origin)}

def mismatched_json(failure):
    return {"status": "mismatched", "failure": failure_json(failure)}

def unchecked_json(prerequisite, failure):
    return {
        "status": "unchecked",
        "prerequisite": prerequisite,
        "failure": failure_json(failure),
    }

def check_json(result):
    if isinstance(result, CheckMatched):
        return {"status": "matched"}
    assert isinstance(result, CheckMismatched)
    return mismatched_json(result.failure)

def conditions_json(checks):
    decode = checks.decode
    source = checks.source
    if isinstance(decode, PrerequisiteFailed):
        decode_wire = mismatched_json(decode.failure)
        digest_wire = unchecked_json("decode", decode.failure)
    else:
        decode_wire = {"status": "matched"}
        projections = {
            name: projection_json(result) for name, result in decode.children.items()
        }
        status = "matched" if all(
            isinstance(result, ProjectionMatched) for result in decode.children.values()
        ) else "mismatched"
        digest_wire = {"status": status, "projections": projections}
    if isinstance(source, PrerequisiteFailed):
        source_wire = mismatched_json(source.failure)
        children = {
            name: unchecked_json("source", source.failure)
            for name in ("coordinate", "observations", "residual")
        }
    else:
        source_wire = {"status": "matched"}
        children = {
            "coordinate": check_json(source.children.coordinate),
            "observations": check_json(source.children.observations),
            "residual": check_json(source.children.residual),
        }
    return {
        "decode": decode_wire,
        "source": source_wire,
        "digest": digest_wire,
        **children,
    }

def outcome_of(name, accepted, checks, certificate):
    return {
        "name": name,
        "accepted": accepted,
        "conditions": conditions_json(checks),
        "residuals": sorted(certificate.residuals.values),
    }

def load_corpus(name="cases.json"):
    raw = (COMPARISON_DIR / name).read_bytes()
    return raw, json.loads(raw)

def load_lean_outcomes(name="lean-outcomes.json"):
    raw = (COMPARISON_DIR / name).read_bytes()
    return raw, json.loads(raw)

def run_corpus(name="cases.json"):
    table = RuleTable.of([(REVISION, comparison_rule)])
    assert isinstance(table, RuleTable)
    _, corpus = load_corpus(name)
    runs = []
    for row in corpus:
        certificate = certificate_of(row)
        expected = expected_of(row)
        provenance = row["provenance"]
        checks = check(table, certificate, expected, provenance)
        result = admit(table, certificate, expected, provenance)
        runs.append((row, certificate, checks, result))
    return runs

def outcomes_of(name="cases.json"):
    return [
        outcome_of(row["name"], isinstance(result, Checked), checks, certificate)
        for row, certificate, checks, result in run_corpus(name)
    ]

class ComparisonFileTests(unittest.TestCase):
    def test_input_files_are_in_canonical_form(self):
        cases_raw, _ = load_corpus()
        outcomes_raw, _ = load_lean_outcomes()
        self.assertEqual(canonical_object_bytes(json.loads(cases_raw)), cases_raw)
        self.assertEqual(canonical_object_bytes(json.loads(outcomes_raw)), outcomes_raw)
        api_cases_raw, _ = load_corpus("residual-set-api-cases-v1.json")
        api_outcomes_raw, _ = load_lean_outcomes("residual-set-api-outcomes-v1.json")
        self.assertEqual(canonical_object_bytes(json.loads(api_cases_raw)), api_cases_raw)
        self.assertEqual(canonical_object_bytes(json.loads(api_outcomes_raw)), api_outcomes_raw)

    def test_wire_corpus_has_twenty_one_cases_with_unique_names(self):
        _, corpus = load_corpus()
        names = [row["name"] for row in corpus]
        self.assertEqual(len(corpus), 21)
        self.assertEqual(len(set(names)), 21)

    def test_wire_residuals_are_in_normal_form(self):
        _, corpus = load_corpus()
        for row in corpus:
            for side in ("certificate", "expected"):
                values = row[side]["residuals"]
                self.assertEqual(values, sorted(set(values)), row["name"])

class ComparisonWithLeanOutcomesTests(unittest.TestCase):
    def test_every_case_matches_the_lean_outcome_in_every_condition_and_projection(self):
        _, lean = load_lean_outcomes()
        outcomes = outcomes_of()
        self.assertEqual(len(outcomes), len(lean))
        for outcome, lean_row in zip(outcomes, lean):
            with self.subTest(case=lean_row["name"]):
                self.assertEqual(outcome, lean_row)

    def test_every_versioned_residual_set_api_case_matches_lean(self):
        _, lean = load_lean_outcomes("residual-set-api-outcomes-v1.json")
        _, cases = load_corpus("residual-set-api-cases-v1.json")
        outcomes = outcomes_of("residual-set-api-cases-v1.json")
        self.assertEqual(len(cases), len(lean))
        for outcome, lean_row in zip(outcomes, lean):
            with self.subTest(case=lean_row["name"]):
                self.assertEqual(outcome, lean_row)
        self.assertTrue(lean[0]["accepted"])
        self.assertEqual(
            lean[1]["conditions"]["residual"]["status"], "mismatched"
        )

    def test_accepted_is_exactly_the_cases_where_every_condition_matches(self):
        for row, _, checks, result in run_corpus():
            with self.subTest(case=row["name"]):
                self.assertEqual(isinstance(result, Checked), checks.all_matched())
                if isinstance(result, Mismatch):
                    self.assertEqual(result.checks, checks)

    def test_both_root_failures_are_reported_together_with_their_unchecked_children(self):
        by_name = {row["name"]: checks for row, _, checks, _ in run_corpus()}
        checks = by_name["both_roots_fail"]
        self.assertIsInstance(checks.decode, PrerequisiteFailed)
        self.assertIsInstance(checks.source, PrerequisiteFailed)
        self.assertEqual(checks.status_at(Condition.DIGEST).failure.expected, "comparison/sha256@2")

    def test_independent_children_failures_are_all_reported_under_source(self):
        by_name = {row["name"]: checks for row, _, checks, _ in run_corpus()}
        children = by_name["all_independent_fail"].source.children
        self.assertIsInstance(children.coordinate, CheckMismatched)
        self.assertIsInstance(children.observations, CheckMismatched)
        self.assertIsInstance(children.residual, CheckMismatched)

    def test_utf8_and_utf16_key_orders_agree_with_the_lean_projection_order(self):
        by_name = {row["name"]: checks for row, _, checks, _ in run_corpus()}
        projections = by_name["digest_utf8_utf16_key_order"].decode.children
        self.assertEqual(list(projections), sorted(projections))
        self.assertEqual(list(projections), ["evidence", "～", "😀"])

    def test_accepted_cases_return_the_certificate_and_the_recomputed_digests(self):
        for row, certificate, _, result in run_corpus():
            if not isinstance(result, Checked):
                continue
            with self.subTest(case=row["name"]):
                self.assertEqual(result.certificate, certificate)
                self.assertEqual(result.recomputed, comparison_rule(
                    certificate.source,
                    certificate.coordinate,
                    certificate.observations,
                    certificate.evidence,
                ))

class CanonicalEvidenceTests(unittest.TestCase):
    def test_json_string_writer_matches_the_reference_for_every_ascii_character(self):
        for code in range(0x80):
            text = chr(code)
            with self.subTest(code=code):
                self.assertEqual(canonical_string(text), reference_write_string(text))

    def test_json_string_writer_matches_the_reference_for_unicode_and_controls(self):
        samples = [
            'quote " backslash \\ newline\n return\r tab\t backspace\b formfeed\f',
            "nul\u0000 unit\u0001 unit-sep\u001f del\u007f",
            "日本語 と 漢字",
            "line\u2028separator\u2029paragraph",
            "",
        ]
        for text in samples:
            with self.subTest(text=text):
                self.assertEqual(canonical_string(text), reference_write_string(text))

if __name__ == "__main__":
    unittest.main()
