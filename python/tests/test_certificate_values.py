import dataclasses
import unittest

from neco_quotient_certificate import (
    Certificate,
    CrossLanguage,
    Expected,
    Mismatch,
    Origin,
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

    def test_certificate_owns_digest_tuple_and_residual_set_copied_from_lists(self):
        digests = [ProjectionDigest("evidence", "d", CrossLanguage("sha256"))]
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
        digests.append(ProjectionDigest("extra", "e", CrossLanguage("sha256")))
        residuals.append("residual-b")
        self.assertIsInstance(certificate.digests, tuple)
        self.assertEqual(certificate.residuals.values, ("residual-a",))
        self.assertEqual(len(certificate.digests), 1)
        self.assertEqual(certificate.residuals, type(certificate.residuals)(["residual-a"]))

    def test_expected_owns_residual_tuple_copied_from_list(self):
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
        base = ProjectionDigest("evidence", "d", CrossLanguage("sha256"))
        self.assertEqual(base, ProjectionDigest("evidence", "d", CrossLanguage("sha256")))
        self.assertNotEqual(base, ProjectionDigest("other", "d", CrossLanguage("sha256")))
        self.assertNotEqual(base, ProjectionDigest("evidence", "e", CrossLanguage("sha256")))
        self.assertNotEqual(base, ProjectionDigest("evidence", "d", WithinRuntime("sha256")))
        self.assertNotEqual(base, ProjectionDigest("evidence", "d", CrossLanguage("other")))

    def test_mismatch_keeps_every_field_and_the_provenance_value(self):
        provenance = object()
        origin = Origin("rule@1", "source-alpha", "rev-1")
        mismatch = Mismatch(
            operation="admit",
            stage="digest",
            expected="a",
            actual="b",
            origin=origin,
            provenance=provenance,
        )
        self.assertIs(mismatch.provenance, provenance)
        self.assertEqual(mismatch.contributing, ())
        self.assertEqual(mismatch.origin, origin)
        with self.assertRaises(dataclasses.FrozenInstanceError):
            mismatch.stage = "residual"


if __name__ == "__main__":
    unittest.main()
