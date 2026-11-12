import dataclasses
import unittest

from neco_quotient_certificate import (
    DuplicateRule,
    Mismatch,
    PrerequisiteFailed,
    RuleTable,
    admit,
)

from _support import REVISION, sample_certificate, sample_expected, sample_rule

def other_rule(source, coordinate, observations, evidence):
    return sample_rule(source, coordinate, observations, evidence)

class RuleTableTests(unittest.TestCase):
    def test_distinct_revisions_build_a_table_and_lookup_returns_the_rule(self):
        table = RuleTable.of([("rule@1", sample_rule), ("rule@2", other_rule)])
        self.assertIsInstance(table, RuleTable)
        self.assertIs(table.lookup("rule@1"), sample_rule)
        self.assertIs(table.lookup("rule@2"), other_rule)
        self.assertIsNone(table.lookup("rule@9"))

    def test_first_repeated_revision_is_rejected_as_duplicate_rule(self):
        result = RuleTable.of(
            [("rule@1", sample_rule), ("rule@2", other_rule), ("rule@1", other_rule)]
        )
        self.assertEqual(result, DuplicateRule(rule_revision="rule@1"))

    def test_first_repeated_revision_in_order_is_reported_when_several_repeat(self):
        result = RuleTable.of(
            [("rule@1", sample_rule), ("rule@2", sample_rule), ("rule@2", sample_rule), ("rule@1", sample_rule)]
        )
        self.assertEqual(result, DuplicateRule(rule_revision="rule@2"))

    def test_direct_construction_is_refused_so_the_duplicate_check_is_not_bypassed(self):
        with self.assertRaises(TypeError):
            RuleTable(_entries=((REVISION, sample_rule),))

    def test_permuted_entries_select_the_same_rule_for_each_revision(self):
        forward = RuleTable.of([("rule@1", sample_rule), ("rule@2", other_rule)])
        reversed_table = RuleTable.of([("rule@2", other_rule), ("rule@1", sample_rule)])
        for revision in ("rule@1", "rule@2"):
            self.assertIs(forward.lookup(revision), reversed_table.lookup(revision))

    def test_admission_result_is_the_same_under_permuted_entries(self):
        certificate = sample_certificate()
        expected = sample_expected()
        forward = RuleTable.of([("rule@1", sample_rule), ("rule@2", other_rule)])
        reversed_table = RuleTable.of([("rule@2", other_rule), ("rule@1", sample_rule)])
        first = admit(forward, certificate, expected, "caller")
        second = admit(reversed_table, certificate, expected, "caller")
        self.assertEqual(dict(first.recomputed), dict(second.recomputed))
        self.assertEqual(first.certificate, second.certificate)

    def test_unregistered_revision_does_not_invoke_any_rule(self):
        calls = []
        def recording_rule(source, coordinate, observations, evidence):
            calls.append(source)
            return sample_rule(source, coordinate, observations, evidence)
        table = RuleTable.of([(REVISION, recording_rule)])
        certificate = dataclasses.replace(sample_certificate(), rule_revision="rule@9")
        result = admit(table, certificate, dataclasses.replace(sample_expected(), rule_revision="rule@9"), "caller")
        self.assertIsInstance(result, Mismatch)
        self.assertEqual(calls, [])
        self.assertIsInstance(result.checks.decode, PrerequisiteFailed)

    def test_table_is_independent_of_the_list_it_was_built_from(self):
        entries = [("rule@1", sample_rule)]
        table = RuleTable.of(entries)
        entries.append(("rule@2", other_rule))
        entries[0] = ("rule@1", other_rule)
        self.assertIsNone(table.lookup("rule@2"))
        self.assertIs(table.lookup("rule@1"), sample_rule)
        result = admit(table, sample_certificate(), sample_expected(), "caller")
        self.assertEqual(dict(result.recomputed), dict(sample_certificate().digests))

if __name__ == "__main__":
    unittest.main()
