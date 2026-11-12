import dataclasses
import unittest

from neco_quotient_certificate import (
    RefinementOutcome,
    Residual,
    ResidualSet,
    Resolved,
    Stopped,
)

class RefinementOutcomeTests(unittest.TestCase):
    def test_three_cases_hold_their_parts(self):
        resolved = Resolved("value")
        residual = Residual("value", ["residual-a", "residual-b"])
        stopped = Stopped("value", ["residual-a"], "budget")
        self.assertEqual(resolved.value, "value")
        self.assertEqual(residual.value, "value")
        self.assertEqual(residual.residuals, ResidualSet(("residual-a", "residual-b")))
        self.assertEqual(stopped.residuals.values, ("residual-a",))
        self.assertEqual(stopped.cause, "budget")

    def test_outcomes_are_values_of_the_union(self):
        outcomes: list[RefinementOutcome[str, str, str]] = [
            Resolved("value"),
            Residual("value", ["residual-a"]),
            Stopped("value", ["residual-a"], "budget"),
        ]
        self.assertEqual([type(item) for item in outcomes], [Resolved, Residual, Stopped])

    def test_equal_cases_with_equal_parts_are_equal(self):
        self.assertEqual(Resolved("value"), Resolved("value"))
        self.assertEqual(
            Residual("value", ["residual-a"]), Residual("value", ["residual-a"])
        )
        self.assertEqual(
            Stopped("value", ["residual-a"], "budget"),
            Stopped("value", ["residual-a"], "budget"),
        )

    def test_residual_order_and_duplicates_do_not_change_equality(self):
        self.assertEqual(
            Residual("value", ["residual-b", "residual-a", "residual-a"]),
            Residual("value", ["residual-a", "residual-b"]),
        )
        self.assertEqual(
            Stopped("value", ["residual-b", "residual-a"], "budget"),
            Stopped("value", ResidualSet(["residual-a", "residual-b"]), "budget"),
        )

    def test_different_residual_members_are_not_equal(self):
        self.assertNotEqual(
            Residual("value", ["residual-a", "residual-b"]),
            Residual("value", ["residual-a", "residual-c"]),
        )
        self.assertNotEqual(
            Residual("value", ["residual-a"]), Residual("value", ["residual-a", "residual-b"])
        )

    def test_different_value_or_cause_is_not_equal(self):
        self.assertNotEqual(Resolved("value"), Resolved("other"))
        self.assertNotEqual(
            Stopped("value", ["residual-a"], "budget"),
            Stopped("value", ["residual-a"], "timeout"),
        )
        self.assertNotEqual(
            Residual("value", ["residual-a"]), Residual("other", ["residual-a"])
        )

    def test_different_cases_are_not_equal(self):
        residuals = ["residual-a"]
        self.assertNotEqual(Resolved("value"), Residual("value", residuals))
        self.assertNotEqual(Residual("value", residuals), Stopped("value", residuals, "budget"))
        self.assertNotEqual(Resolved("value"), Stopped("value", [], "budget"))
        self.assertNotEqual(Resolved("value"), Residual("value", []))

    def test_values_are_frozen_and_copy_residual_lists(self):
        residuals = ["residual-a"]
        residual = Residual("value", residuals)
        residuals.append("residual-b")
        self.assertEqual(residual.residuals.values, ("residual-a",))
        with self.assertRaises(dataclasses.FrozenInstanceError):
            residual.value = "other"

if __name__ == "__main__":
    unittest.main()
