import dataclasses
import unittest

from neco_quotient_certificate import (
    Checked,
    CheckMatched,
    Condition,
    CrossLanguage,
    Matched,
    Mismatch,
    Mismatched,
    PrerequisiteEstablished,
    PrerequisiteFailed,
    ProjectionCertificateOnly,
    ProjectionDifferent,
    ProjectionMatched,
    ProjectionRecomputedOnly,
    ProjectionDigest,
    RuleTable,
    SourceRef,
    UncheckedByDecode,
    UncheckedBySource,
    WithinRuntime,
    admit,
    check,
)
from neco_quotient_certificate.failure import _MISMATCH_SEAL

from _support import CONDITIONS, REVISION, break_condition, sample_certificate, sample_expected, sample_table

def rejected(table, certificate, expected, provenance="caller"):
    result = admit(table, certificate, expected, provenance)
    if isinstance(result, Checked):
        raise AssertionError("the certificate is expected to be rejected")
    return result

def other_digest(name_value):
    return ProjectionDigest(name_value, CrossLanguage("sha256"))

class SingleConditionTests(unittest.TestCase):
    def test_residual_break_is_reported_only_at_residual(self):
        checks = rejected(sample_table(), break_condition(sample_certificate(), Condition.RESIDUAL), sample_expected()).checks
        failed = [c for c in CONDITIONS if isinstance(checks.status_at(c), Mismatched)]
        self.assertEqual(failed, [Condition.RESIDUAL])

    def test_each_break_is_reported_at_its_condition_and_its_recomputed_dependents(self):
        table = sample_table()
        expected_failed = {
            Condition.SOURCE: [Condition.SOURCE, Condition.DIGEST],
            Condition.COORDINATE: [Condition.COORDINATE, Condition.DIGEST],
            Condition.OBSERVATIONS: [Condition.OBSERVATIONS, Condition.DIGEST],
        }
        for condition, failed_expected in expected_failed.items():
            with self.subTest(condition=condition):
                checks = rejected(table, break_condition(sample_certificate(), condition), sample_expected()).checks
                failed = [c for c in CONDITIONS if isinstance(checks.status_at(c), Mismatched)]
                self.assertEqual(sorted(failed), sorted(failed_expected))

    def test_a_source_break_leaves_the_digest_checked_against_its_own_recomputation(self):
        checks = rejected(sample_table(), break_condition(sample_certificate(), Condition.SOURCE), sample_expected()).checks
        self.assertIsInstance(checks.status_at(Condition.DIGEST), Mismatched)
        self.assertIsInstance(checks.status_at(Condition.DECODE), Matched)
        self.assertIsInstance(checks.status_at(Condition.SOURCE), Mismatched)
        for child in (Condition.COORDINATE, Condition.OBSERVATIONS, Condition.RESIDUAL):
            self.assertIsInstance(checks.status_at(child), UncheckedBySource)

    def test_a_decode_break_leaves_the_source_branch_checked(self):
        table = sample_table()
        certificate = dataclasses.replace(sample_certificate(), rule_revision="rule@2")
        checks = rejected(table, certificate, sample_expected()).checks
        self.assertIsInstance(checks.status_at(Condition.DECODE), Mismatched)
        self.assertIsInstance(checks.status_at(Condition.DIGEST), UncheckedByDecode)
        self.assertIsInstance(checks.status_at(Condition.SOURCE), Matched)
        self.assertIsInstance(checks.status_at(Condition.RESIDUAL), Matched)

    def test_unknown_revision_is_reported_at_decode_with_the_table_expectation(self):
        certificate = dataclasses.replace(sample_certificate(), rule_revision="rule@9")
        result = rejected(sample_table(), certificate, dataclasses.replace(sample_expected(), rule_revision="rule@9"))
        failure = result.checks.decode.failure
        self.assertEqual(failure.expected, "rule in table")
        self.assertEqual(failure.actual, "rule@9")

class FailureConditionTests(unittest.TestCase):
    def collect(self, checks):
        found = []
        if isinstance(checks.decode, PrerequisiteFailed):
            found.append((Condition.DECODE, checks.decode.failure))
        if isinstance(checks.source, PrerequisiteFailed):
            found.append((Condition.SOURCE, checks.source.failure))
        else:
            children = checks.source.children
            for condition, result in (
                (Condition.COORDINATE, children.coordinate),
                (Condition.OBSERVATIONS, children.observations),
                (Condition.RESIDUAL, children.residual),
            ):
                if not isinstance(result, CheckMatched):
                    found.append((condition, result.failure))
        return found

    def test_each_failure_holds_its_own_condition_after_extraction(self):
        table = sample_table()
        certificates = {
            Condition.DECODE: dataclasses.replace(sample_certificate(), rule_revision="rule@2"),
            Condition.SOURCE: break_condition(sample_certificate(), Condition.SOURCE),
            Condition.COORDINATE: break_condition(sample_certificate(), Condition.COORDINATE),
            Condition.OBSERVATIONS: break_condition(sample_certificate(), Condition.OBSERVATIONS),
            Condition.RESIDUAL: break_condition(sample_certificate(), Condition.RESIDUAL),
        }
        for condition, certificate in certificates.items():
            with self.subTest(condition=condition):
                found = self.collect(rejected(table, certificate, sample_expected()).checks)
                self.assertIn(condition, [c for c, _ in found])
                extracted = [failure for _, failure in found]
                for expected_condition, failure in found:
                    self.assertIs(failure.condition, expected_condition)
                self.assertIn(condition, [f.condition for f in extracted])

    def test_unknown_revision_failure_holds_decode(self):
        certificate = dataclasses.replace(sample_certificate(), rule_revision="rule@9")
        result = rejected(sample_table(), certificate, dataclasses.replace(sample_expected(), rule_revision="rule@9"))
        self.assertIs(result.checks.decode.failure.condition, Condition.DECODE)

    def test_all_source_children_failing_hold_distinct_conditions(self):
        certificate = dataclasses.replace(
            sample_certificate(), coordinate="coord-b", observations="observations-b", residuals=("residual-c",)
        )
        found = self.collect(rejected(sample_table(), certificate, sample_expected()).checks)
        by_collection = {failure.condition for _, failure in found}
        self.assertEqual(by_collection, {Condition.COORDINATE, Condition.OBSERVATIONS, Condition.RESIDUAL})

class SimultaneousFailureTests(unittest.TestCase):
    def test_all_three_source_children_failing_together_are_each_mismatched(self):
        certificate = dataclasses.replace(
            sample_certificate(), coordinate="coord-b", observations="observations-b", residuals=("residual-c",)
        )
        checks = rejected(sample_table(), certificate, sample_expected()).checks
        for child in (Condition.COORDINATE, Condition.OBSERVATIONS, Condition.RESIDUAL):
            with self.subTest(child=child):
                self.assertIsInstance(checks.status_at(child), Mismatched)
        self.assertIsInstance(checks.status_at(Condition.SOURCE), Matched)

    def test_both_roots_failing_leave_every_child_unchecked_with_its_own_prerequisite(self):
        certificate = dataclasses.replace(
            sample_certificate(), rule_revision="rule@2", source=SourceRef("source-beta", "rev-1")
        )
        checks = rejected(sample_table(), certificate, sample_expected()).checks
        self.assertIsInstance(checks.decode, PrerequisiteFailed)
        self.assertIsInstance(checks.source, PrerequisiteFailed)
        self.assertIsInstance(checks.status_at(Condition.DIGEST), UncheckedByDecode)
        for child in (Condition.COORDINATE, Condition.OBSERVATIONS, Condition.RESIDUAL):
            self.assertIsInstance(checks.status_at(child), UncheckedBySource)

    def test_a_failed_parent_hides_child_values_that_would_otherwise_differ(self):
        certificate = dataclasses.replace(
            sample_certificate(), source=SourceRef("source-beta", "rev-1"), coordinate="coord-b"
        )
        checks = rejected(sample_table(), certificate, sample_expected()).checks
        self.assertIsInstance(checks.status_at(Condition.COORDINATE), UncheckedBySource)
        self.assertIs(checks.status_at(Condition.COORDINATE).failure, checks.source.failure)

    def test_a_failed_parent_with_child_values_that_match_leaves_children_unchecked(self):
        certificate = break_condition(sample_certificate(), Condition.SOURCE)
        checks = rejected(sample_table(), certificate, sample_expected()).checks
        self.assertEqual(
            sorted(
                condition for condition in CONDITIONS
                if isinstance(checks.status_at(condition), UncheckedBySource)
            ),
            sorted([Condition.COORDINATE, Condition.OBSERVATIONS, Condition.RESIDUAL]),
        )

    def test_the_mismatch_names_every_failed_condition_and_no_unchecked_one(self):
        certificate = dataclasses.replace(sample_certificate(), observations="observations-b", residuals=("residual-c",))
        checks = rejected(sample_table(), certificate, sample_expected()).checks
        failed = [c for c in CONDITIONS if isinstance(checks.status_at(c), Mismatched)]
        self.assertEqual(failed, [Condition.OBSERVATIONS, Condition.DIGEST, Condition.RESIDUAL])

class StatusAccessorTests(unittest.TestCase):
    def test_unchecked_holds_exactly_when_the_prerequisite_fails(self):
        cases = [
            sample_certificate(),
            break_condition(sample_certificate(), Condition.SOURCE),
            dataclasses.replace(sample_certificate(), rule_revision="rule@2"),
            break_condition(sample_certificate(), Condition.DIGEST),
            break_condition(sample_certificate(), Condition.RESIDUAL),
        ]
        for certificate in cases:
            checks = check(sample_table(), certificate, sample_expected(), "caller")
            for condition in CONDITIONS:
                prerequisite = condition.prerequisite()
                unchecked = isinstance(checks.status_at(condition), (UncheckedByDecode, UncheckedBySource))
                failed_prerequisite = prerequisite is not None and isinstance(
                    checks.status_at(prerequisite), Mismatched
                )
                with self.subTest(condition=condition):
                    self.assertEqual(unchecked, failed_prerequisite)

    def test_prerequisite_relation_matches_the_specified_dependency_structure(self):
        self.assertIsNone(Condition.DECODE.prerequisite())
        self.assertIsNone(Condition.SOURCE.prerequisite())
        self.assertIs(Condition.DIGEST.prerequisite(), Condition.DECODE)
        for child in (Condition.COORDINATE, Condition.OBSERVATIONS, Condition.RESIDUAL):
            self.assertIs(child.prerequisite(), Condition.SOURCE)

    def test_check_returns_the_same_checks_as_a_rejected_admission(self):
        certificate = break_condition(sample_certificate(), Condition.COORDINATE)
        checks = check(sample_table(), certificate, sample_expected(), "caller")
        self.assertEqual(rejected(sample_table(), certificate, sample_expected()).checks, checks)

    def test_failures_keep_the_input_provenance_and_the_certificate_origin(self):
        provenance = object()
        result = admit(sample_table(), break_condition(sample_certificate(), Condition.RESIDUAL), sample_expected(), provenance)
        self.assertIs(result.provenance, provenance)
        self.assertEqual(result.origin.rule_revision, REVISION)
        self.assertEqual(result.origin.source_identity, "source-alpha")
        self.assertEqual(result.origin.source_revision, "rev-1")

class ProjectionNameTests(unittest.TestCase):
    def projection_result(self, certificate_digests, recomputed_digests=None):
        def rule(source, coordinate, observations, evidence):
            return dict(recomputed_digests if recomputed_digests is not None else {})
        table = RuleTable.of([(REVISION, rule)])
        certificate = dataclasses.replace(sample_certificate(), digests=certificate_digests)
        return check(table, certificate, sample_expected(), "caller").decode.children

    def test_names_on_one_side_only_are_classified_by_side(self):
        results = self.projection_result(
            {"extra": other_digest("e")}, {"recomputed": other_digest("r")}
        )
        self.assertIsInstance(results["extra"], ProjectionCertificateOnly)
        self.assertIsInstance(results["recomputed"], ProjectionRecomputedOnly)

    def test_same_name_with_different_value_or_scope_is_different(self):
        value = self.projection_result({"p": other_digest("a")}, {"p": other_digest("b")})
        scope = self.projection_result(
            {"p": other_digest("a")}, {"p": ProjectionDigest("a", WithinRuntime("sha256"))}
        )
        self.assertIsInstance(value["p"], ProjectionDifferent)
        self.assertIsInstance(scope["p"], ProjectionDifferent)

    def test_same_name_with_equal_value_and_scope_is_matched(self):
        results = self.projection_result({"p": other_digest("a")}, {"p": other_digest("a")})
        self.assertIsInstance(results["p"], ProjectionMatched)

    def test_many_names_are_classified_together_in_code_point_order(self):
        certificate = {
            "～": other_digest("same"),
            "😀": other_digest("cert"),
            "alpha": other_digest("a"),
        }
        recomputed = {
            "～": other_digest("same"),
            "😀": other_digest("recomputed"),
            "beta": other_digest("b"),
        }
        results = self.projection_result(certificate, recomputed)
        self.assertEqual(list(results), ["alpha", "beta", "～", "😀"])
        self.assertIsInstance(results["alpha"], ProjectionCertificateOnly)
        self.assertIsInstance(results["beta"], ProjectionRecomputedOnly)
        self.assertIsInstance(results["～"], ProjectionMatched)
        self.assertIsInstance(results["😀"], ProjectionDifferent)

    def test_changing_one_name_changes_only_that_name_result(self):
        base = {"a": other_digest("1"), "b": other_digest("2")}
        changed = {"a": other_digest("1"), "b": other_digest("3")}
        before = self.projection_result(base, base)
        after = self.projection_result(changed, base)
        self.assertEqual(before["a"], after["a"])
        self.assertIsInstance(after["b"], ProjectionDifferent)

    def test_insertion_order_of_the_certificate_digests_does_not_change_the_result(self):
        forward = {"a": other_digest("1"), "b": other_digest("2"), "～": other_digest("3")}
        backward = dict(reversed(list(forward.items())))
        base = {"a": other_digest("1"), "b": other_digest("9")}
        table = RuleTable.of([(REVISION, lambda s, c, o, e: base)])
        first = check(table, dataclasses.replace(sample_certificate(), digests=forward), sample_expected(), "caller")
        second = check(table, dataclasses.replace(sample_certificate(), digests=backward), sample_expected(), "caller")
        self.assertEqual(first, second)
        self.assertEqual(list(first.decode.children), list(second.decode.children))

class CheckedValueTests(unittest.TestCase):
    def test_accepted_certificate_has_checks_that_all_match(self):
        result = admit(sample_table(), sample_certificate(), sample_expected(), "caller")
        self.assertIsInstance(result, Checked)
        checks = check(sample_table(), sample_certificate(), sample_expected(), "caller")
        self.assertTrue(checks.all_matched())
        self.assertIsInstance(checks.source, PrerequisiteEstablished)
        self.assertIsInstance(checks.source.children.residual, CheckMatched)

    def test_mismatch_cannot_be_constructed_for_an_accepted_checks_value(self):
        checks = check(sample_table(), sample_certificate(), sample_expected(), "caller")
        with self.assertRaises(ValueError):
            Mismatch(checks=checks, _seal=_MISMATCH_SEAL)

    def test_mismatch_cannot_be_constructed_publicly(self):
        checks = rejected(sample_table(), break_condition(sample_certificate(), Condition.COORDINATE), sample_expected()).checks
        with self.assertRaises(TypeError):
            Mismatch(checks=checks)

class UnknownConditionTests(unittest.TestCase):
    def test_status_at_rejects_a_non_condition_even_when_source_failed(self):
        checks = rejected(sample_table(), break_condition(sample_certificate(), Condition.SOURCE), sample_expected()).checks
        for value in ("source", None, 7):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    checks.status_at(value)

if __name__ == "__main__":
    unittest.main()
