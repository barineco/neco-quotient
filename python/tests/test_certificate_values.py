import dataclasses
import unittest

from neco_quotient_certificate import (
    Certificate,
    CrossLanguage,
    Expected,
    ProjectionDigest,
    SourceRef,
    WithinRuntime,
)

from _support import sample_certificate, sample_expected

class CertificateValueTests(unittest.TestCase):
    def test_values_are_frozen(self):
        certificate = sample_certificate()
        with self.assertRaises(dataclasses.FrozenInstanceError):
            certificate.coordinate = "coord-b"
        with self.assertRaises(dataclasses.FrozenInstanceError):
            sample_expected().observations = "observations-b"

    def test_certificate_owns_digest_mapping_and_residual_set_copied_from_lists(self):
        digests = {"evidence": ProjectionDigest("d", CrossLanguage("sha256"))}
        residuals = ["residual-a"]
        certificate = Certificate(
            rule_revision="rule@1",
            source=SourceRef("source-alpha", "rev-1"),
            coordinate="coord-a",
            digests=digests,
            residuals=residuals,
            observations="observations-a",
            evidence="evidence-a",
        )
        digests["extra"] = ProjectionDigest("e", CrossLanguage("sha256"))
        residuals.append("residual-b")
        self.assertEqual(list(certificate.digests), ["evidence"])
        self.assertEqual(certificate.residuals.values, ("residual-a",))
        with self.assertRaises(TypeError):
            certificate.digests["evidence"] = ProjectionDigest("x", CrossLanguage("sha256"))
        self.assertEqual(certificate.residuals, type(certificate.residuals)(["residual-a"]))

    def test_expected_owns_residual_set_copied_from_list(self):
        residuals = ["residual-a"]
        expected = Expected(
            rule_revision="rule@1",
            source=SourceRef("source-alpha", "rev-1"),
            coordinate="coord-a",
            observations="observations-a",
            residuals=residuals,
        )
        residuals.append("residual-b")
        self.assertEqual(expected.residuals.values, ("residual-a",))

    def test_digest_scope_kinds_with_same_name_are_not_equal(self):
        self.assertNotEqual(WithinRuntime("sha256"), CrossLanguage("sha256"))
        self.assertEqual(CrossLanguage("sha256"), CrossLanguage("sha256"))

    def test_projection_digest_equality_compares_every_field(self):
        base = ProjectionDigest("d", CrossLanguage("sha256"))
        self.assertEqual(base, ProjectionDigest("d", CrossLanguage("sha256")))
        self.assertNotEqual(base, ProjectionDigest("e", CrossLanguage("sha256")))
        self.assertNotEqual(base, ProjectionDigest("d", WithinRuntime("sha256")))
        self.assertNotEqual(base, ProjectionDigest("d", CrossLanguage("other")))

    def test_certificate_digest_mappings_with_equal_entries_are_equal(self):
        first = Certificate("rule@1", SourceRef("a", "r"), "c", {"x": ProjectionDigest("1", CrossLanguage("s"))}, (), "o", "e")
        second = Certificate("rule@1", SourceRef("a", "r"), "c", {"x": ProjectionDigest("1", CrossLanguage("s"))}, (), "o", "e")
        self.assertEqual(first, second)

if __name__ == "__main__":
    unittest.main()
