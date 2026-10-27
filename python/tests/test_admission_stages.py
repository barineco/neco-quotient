import dataclasses
import unittest

from neco_quotient_certificate import (
    Checked,
    Certificate,
    Expected,
    CrossLanguage,
    Mismatch,
    ProjectionDigest,
    RuleTable,
    SourceRef,
    WithinRuntime,
    admit,
)

from _support import (
    STAGES,
    REVISION,
    break_stage,
    sample_certificate,
    sample_expected,
    sample_table,
)


def failure(table, certificate, expected, provenance="caller"):
    result = admit(table, certificate, expected, provenance)
    if isinstance(result, Checked):
        raise AssertionError("the certificate is expected to be rejected")
    return result


class AdmissionStageTests(unittest.TestCase):
    def test_each_stage_alone_is_reported_at_that_stage(self):
        table = sample_table()
        for stage in STAGES[1:]:
            with self.subTest(stage=stage):
                result = failure(table, break_stage(sample_certificate(), stage), sample_expected())
                self.assertEqual(result.stage, stage)

    def test_first_failing_stage_is_reported_before_all_later_stages(self):
        table = sample_table()
        for index, stage in enumerate(STAGES[1:], start=1):
            with self.subTest(stage=stage):
                certificate = sample_certificate()
                for later in STAGES[index:]:
                    certificate = break_stage(certificate, later)
                result = failure(table, certificate, sample_expected())
                self.assertEqual(result.stage, stage)

    def test_version_mismatch_is_reported_before_unknown_revision(self):
        certificate = dataclasses.replace(sample_certificate(), rule_revision="rule@2")
        result = failure(sample_table(), certificate, sample_expected())
        self.assertEqual(result.stage, "decode")
        self.assertEqual(result.expected, REVISION)
        self.assertEqual(result.actual, "rule@2")

    def test_unknown_revision_is_reported_at_decode_when_versions_agree(self):
        certificate = dataclasses.replace(sample_certificate(), rule_revision="rule@9")
        expected = dataclasses.replace(sample_expected(), rule_revision="rule@9")
        result = failure(sample_table(), certificate, expected)
        self.assertEqual(result.stage, "decode")
        self.assertEqual(result.expected, "rule in table")
        self.assertEqual(result.actual, "rule@9")

    def test_origin_is_taken_from_the_certificate_and_provenance_is_the_same_value(self):
        provenance = object()
        certificate = break_stage(sample_certificate(), "source")
        result = admit(sample_table(), certificate, sample_expected(), provenance)
        self.assertIsInstance(result, Mismatch)
        self.assertIs(result.provenance, provenance)
        self.assertEqual(result.operation, "admit")
        self.assertEqual(result.origin.rule_revision, REVISION)
        self.assertEqual(result.origin.source_identity, "source-beta")
        self.assertEqual(result.origin.source_revision, "rev-1")
        self.assertEqual(result.contributing, ())

    def test_expected_and_actual_are_both_sides_of_the_failed_comparison(self):
        result = failure(sample_table(), break_stage(sample_certificate(), "observations"), sample_expected())
        self.assertEqual(result.expected, repr("observations-a"))
        self.assertEqual(result.actual, repr("observations-b"))

    def test_digest_scope_kind_is_compared_not_only_the_text(self):
        certificate = sample_certificate()
        digest = certificate.digests[0]
        swapped = dataclasses.replace(
            digest, scope=WithinRuntime(digest.scope.name)
        )
        certificate = dataclasses.replace(certificate, digests=(swapped,))
        result = failure(sample_table(), certificate, sample_expected())
        self.assertEqual(result.stage, "digest")

    def test_digest_order_and_length_are_compared(self):
        certificate = sample_certificate()
        extra = ProjectionDigest("other", "x", CrossLanguage("sha256"))
        longer = dataclasses.replace(certificate, digests=certificate.digests + (extra,))
        self.assertEqual(failure(sample_table(), longer, sample_expected()).stage, "digest")
        reordered = dataclasses.replace(
            certificate, digests=(extra, certificate.digests[0])
        )
        self.assertEqual(failure(sample_table(), reordered, sample_expected()).stage, "digest")

    def test_residual_order_and_duplicates_do_not_change_membership(self):
        certificate = dataclasses.replace(
            sample_certificate(), residuals=("residual-b", "residual-a")
        )
        expected = dataclasses.replace(sample_expected(), residuals=("residual-a", "residual-b", "residual-a"))
        self.assertIsInstance(admit(sample_table(), certificate, expected, "caller"), Checked)

    def test_different_residual_membership_is_reported_at_residual(self):
        certificate = dataclasses.replace(sample_certificate(), residuals=("residual-a", "residual-c"))
        self.assertEqual(failure(sample_table(), certificate, sample_expected()).stage, "residual")

    def test_accepted_certificate_returns_the_recomputed_digest_tuple(self):
        certificate = sample_certificate()
        result = admit(sample_table(), certificate, sample_expected(), "caller")
        self.assertIsInstance(result, Checked)
        self.assertEqual(result.recomputed, certificate.digests)
        self.assertIsInstance(result.recomputed, tuple)
        self.assertEqual(result.certificate, certificate)
        self.assertEqual(result.source, SourceRef("source-alpha", "rev-1"))

    def test_generic_type_arguments_of_other_kinds_are_admitted(self):
        def count_rule(source, coordinate, observations, evidence):
            return (
                ProjectionDigest(
                    "count", str(coordinate + evidence["n"]), WithinRuntime("py")
                ),
            )

        table = RuleTable.of([("count@1", count_rule)])
        self.assertIsInstance(table, RuleTable)
        certificate = Certificate(
            rule_revision="count@1",
            source=SourceRef(("id", 1), 7),
            coordinate=3,
            digests=[ProjectionDigest("count", "5", WithinRuntime("py"))],
            residuals=[b"\x01", b"\x02"],
            observations=frozenset({"a"}),
            evidence={"n": 2},
        )
        expected = Expected(
            rule_revision="count@1",
            source=SourceRef(("id", 1), 7),
            coordinate=3,
            observations=frozenset({"a"}),
            residuals=[b"\x01", b"\x02"],
        )
        result = admit(table, certificate, expected, ("caller", 1))
        self.assertIsInstance(result, Checked)
        self.assertEqual(result.recomputed[0].digest, "5")

    def test_generic_failure_still_reports_the_first_stage_for_non_string_types(self):
        table = RuleTable.of([("count@1", lambda s, c, d, e: ())])
        certificate = Certificate(
            rule_revision="count@1",
            source=SourceRef(1, 2),
            coordinate=3,
            digests=(),
            residuals=(),
            observations=frozenset(),
            evidence={},
        )
        expected = Expected(
            rule_revision="count@1",
            source=SourceRef(1, 2),
            coordinate=4,
            observations=frozenset(),
            residuals=(),
        )
        result = failure(table, certificate, expected)
        self.assertEqual(result.stage, "coordinate")
        self.assertEqual(result.origin.source_identity, "1")


if __name__ == "__main__":
    unittest.main()
