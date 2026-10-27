import dataclasses
import inspect
import unittest

import neco_quotient_certificate
from neco_quotient_certificate import Checked, RuleTable, admit

from _support import sample_certificate, sample_expected, sample_table


class CheckedBoundaryTests(unittest.TestCase):
    def test_public_construction_is_refused(self):
        table = sample_table()
        with self.assertRaises(TypeError):
            Checked(certificate=sample_certificate(), recomputed=(), _table=table)

    def test_construction_with_a_foreign_seal_is_refused(self):
        table = sample_table()
        with self.assertRaises(TypeError):
            Checked(
                certificate=sample_certificate(),
                recomputed=(),
                _table=table,
                _seal=object(),
            )

    def test_replace_cannot_reuse_a_seal_to_forge_a_checked_value(self):
        table = sample_table()
        checked = admit(table, sample_certificate(), sample_expected(), "caller")
        self.assertIsInstance(checked, Checked)
        other = dataclasses.replace(sample_certificate(), coordinate="coord-b")
        with self.assertRaises(TypeError):
            dataclasses.replace(checked, certificate=other)

    def test_seal_has_no_public_default(self):
        parameter = inspect.signature(Checked).parameters["_seal"]
        self.assertIsNone(parameter.default)

    def test_admit_yields_a_checked_value_for_an_accepted_certificate(self):
        checked = admit(sample_table(), sample_certificate(), sample_expected(), "caller")
        self.assertIsInstance(checked, Checked)
        self.assertEqual(checked.certificate, sample_certificate())

    def test_public_exports_exclude_seals_and_makers(self):
        exported = set(neco_quotient_certificate.__all__)
        self.assertNotIn("_CHECK_SEAL", exported)
        self.assertNotIn("_TABLE_SEAL", exported)
        for name in exported:
            self.assertFalse(name.startswith("_"), name)

    def test_rule_table_public_construction_is_refused(self):
        with self.assertRaises(TypeError):
            RuleTable(_entries=())


if __name__ == "__main__":
    unittest.main()
