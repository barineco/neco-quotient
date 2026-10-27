import hashlib
import json
import unittest
from collections import Counter

from neco_quotient_certificate import (
    Certificate,
    Checked,
    CrossLanguage,
    Expected,
    Mismatch,
    ProjectionDigest,
    RuleTable,
    SourceRef,
    WithinRuntime,
    admit,
)

from _support import COMPARISON_DIR, reference_write_string


REVISION = "comparison/sha256@1"


def canonical_string(text):
    return json.dumps(text, ensure_ascii=False).encode("utf-8")


def comparison_rule(source, coordinate, observations, evidence):
    digest = hashlib.sha256(canonical_string(evidence)).hexdigest()
    return (ProjectionDigest("evidence", digest, CrossLanguage("sha256")),)


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
        digests=tuple(
            ProjectionDigest(item["projection"], item["digest"], scope_of(item["scope"]))
            for item in wire["digests"]
        ),
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


def outcome_of(name, result, certificate):
    residuals = sorted(certificate.residuals.values)
    if isinstance(result, Checked):
        return {"name": name, "accepted": True, "residuals": residuals}
    assert isinstance(result, Mismatch)
    return {
        "name": name,
        "accepted": False,
        "residuals": residuals,
        "failure": {
            "operation": result.operation,
            "stage": result.stage,
            "origin": {
                "rule_revision": result.origin.rule_revision,
                "source_identity": result.origin.source_identity,
                "source_revision": result.origin.source_revision,
            },
        },
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
        provenance = row["provenance"]
        result = admit(table, certificate_of(row), expected_of(row), provenance)
        runs.append((row, result))
    return runs


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

    def test_wire_corpus_has_nine_cases_with_unique_names(self):
        _, corpus = load_corpus()
        names = [row["name"] for row in corpus]
        self.assertEqual(len(corpus), 9)
        self.assertEqual(len(set(names)), 9)

    def test_wire_residuals_are_in_normal_form(self):
        _, corpus = load_corpus()
        for row in corpus:
            for side in ("certificate", "expected"):
                values = row[side]["residuals"]
                self.assertEqual(values, sorted(set(values)), row["name"])

    def test_versioned_residual_set_api_cases_match_lean(self):
        _, cases = load_corpus("residual-set-api-cases-v1.json")
        _, lean = load_lean_outcomes("residual-set-api-outcomes-v1.json")
        runs = run_corpus("residual-set-api-cases-v1.json")
        self.assertEqual(len(cases), 2)
        self.assertEqual(len(runs), len(lean))
        for (row, result), lean_row in zip(runs, lean):
            with self.subTest(case=row["name"]):
                self.assertEqual(
                    outcome_of(row["name"], result, certificate_of(row)), lean_row
                )
        self.assertTrue(lean[0]["accepted"])
        self.assertEqual(lean[1]["failure"]["stage"], "residual")


class ComparisonWithLeanOutcomesTests(unittest.TestCase):
    def test_every_case_matches_the_lean_outcome_by_name_acceptance_and_failure(self):
        _, lean = load_lean_outcomes()
        runs = run_corpus()
        self.assertEqual(len(runs), len(lean))
        for (row, result), lean_row in zip(runs, lean):
            with self.subTest(case=row["name"]):
                self.assertEqual(row["name"], lean_row["name"])
                self.assertEqual(outcome_of(row["name"], result, certificate_of(row)), lean_row)

    def test_accepted_and_failing_counts_match_the_corpus_design(self):
        results = [result for _, result in run_corpus()]
        self.assertEqual(sum(isinstance(result, Checked) for result in results), 2)
        self.assertEqual(sum(isinstance(result, Mismatch) for result in results), 7)

    def test_stage_counts_cover_each_stage_and_both_decode_variants(self):
        counts = Counter()
        for _, result in run_corpus():
            if isinstance(result, Checked):
                counts["accepted"] += 1
            else:
                counts[result.stage] += 1
        self.assertEqual(
            counts,
            Counter(
                {
                    "accepted": 2,
                    "decode": 2,
                    "source": 2,
                    "coordinate": 1,
                    "observations": 1,
                    "digest": 1,
                }
            ),
        )

    def test_both_decode_failures_name_the_expected_revision_or_the_table(self):
        expected_values = sorted(
            result.expected
            for _, result in run_corpus()
            if isinstance(result, Mismatch) and result.stage == "decode"
        )
        self.assertEqual(expected_values, ["comparison/sha256@2", "rule in table"])

    def test_failures_keep_the_input_provenance_and_the_certificate_origin(self):
        for row, result in run_corpus():
            if not isinstance(result, Mismatch):
                continue
            with self.subTest(case=row["name"]):
                self.assertEqual(result.provenance, f"caller/{row['name']}")
                self.assertEqual(result.contributing, ())
                wire = row["certificate"]
                self.assertEqual(result.origin.rule_revision, wire["rule_revision"])
                self.assertEqual(result.origin.source_identity, wire["source"]["identity"])
                self.assertEqual(result.origin.source_revision, wire["source"]["revision"])

    def test_accepted_cases_return_the_certificate_and_the_recomputed_digests(self):
        for row, result in run_corpus():
            if not isinstance(result, Checked):
                continue
            with self.subTest(case=row["name"]):
                self.assertEqual(result.certificate, certificate_of(row))
                self.assertEqual(result.recomputed, certificate_of(row).digests)

    def test_recorded_digests_equal_independent_hashes_except_intended_corruptions(self):
        intended = {"digest", "source_with_later_stages"}
        for row in run_corpus():
            row = row[0]
            with self.subTest(case=row["name"]):
                recorded = row["certificate"]["digests"][0]["digest"]
                independent = hashlib.sha256(
                    canonical_string(row["certificate"]["evidence"])
                ).hexdigest()
                self.assertEqual(recorded == independent, row["name"] not in intended)


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
