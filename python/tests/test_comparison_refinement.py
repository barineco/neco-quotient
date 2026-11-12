import json
import unittest

from neco_quotient_certificate import Residual, Resolved, Stopped

from _support import REPOSITORY_ROOT

REFINEMENT_DIR = REPOSITORY_ROOT / "comparison" / "refinement-outcome"

def canonical_bytes(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")

def load(name):
    raw = (REFINEMENT_DIR / name).read_bytes()
    return raw, json.loads(raw)

def outcome_of(wire):
    kind = wire["kind"]
    if kind == "resolved":
        return Resolved(wire["value"])
    if kind == "residual":
        return Residual(wire["value"], wire["residuals"])
    assert kind == "stopped"
    return Stopped(wire["value"], wire["residuals"], wire["cause"])

def outcome_json(outcome):
    if isinstance(outcome, Resolved):
        return {"kind": "resolved", "value": outcome.value}
    if isinstance(outcome, Residual):
        return {
            "kind": "residual",
            "value": outcome.value,
            "residuals": sorted(outcome.residuals.values),
        }
    assert isinstance(outcome, Stopped)
    return {
        "kind": "stopped",
        "value": outcome.value,
        "residuals": sorted(outcome.residuals.values),
        "cause": outcome.cause,
    }

def outcomes_of(corpus):
    results = []
    for row in corpus:
        left = outcome_of(row["left"])
        right = outcome_of(row["right"])
        results.append(
            {
                "name": row["name"],
                "left": outcome_json(left),
                "right": outcome_json(right),
                "same": left == right,
            }
        )
    return results

class RefinementComparisonTests(unittest.TestCase):
    def test_input_files_are_in_canonical_form(self):
        for name in ("cases.json", "lean-outcomes.json"):
            raw, value = load(name)
            self.assertEqual(canonical_bytes(value), raw)

    def test_outcomes_equal_lean_outcomes(self):
        _, corpus = load("cases.json")
        _, lean = load("lean-outcomes.json")
        self.assertEqual(outcomes_of(corpus), lean)

    def test_cases_have_unique_names_and_both_verdicts(self):
        _, corpus = load("cases.json")
        _, lean = load("lean-outcomes.json")
        names = [row["name"] for row in corpus]
        self.assertEqual(len(set(names)), len(names))
        self.assertEqual(names, [row["name"] for row in lean])
        verdicts = {row["same"] for row in lean}
        self.assertEqual(verdicts, {True, False})

    def test_reordered_inputs_stay_the_same_and_swapped_cases_differ(self):
        _, lean = load("lean-outcomes.json")
        by_name = {row["name"]: row["same"] for row in lean}
        self.assertTrue(by_name["residual_order_and_duplicates"])
        self.assertTrue(by_name["stopped_order_and_duplicates"])
        for name in ("case_resolved_residual", "case_residual_stopped", "case_resolved_stopped"):
            self.assertFalse(by_name[name])

    def test_ordered_comparison_is_detected_as_a_mutation(self):
        _, corpus = load("cases.json")
        _, lean = load("lean-outcomes.json")
        expected = {row["name"]: row["same"] for row in lean}
        mutated = {}
        for row in corpus:
            left, right = row["left"], row["right"]
            mutated[row["name"]] = left == right
        self.assertNotEqual(mutated, expected)

if __name__ == "__main__":
    unittest.main()
