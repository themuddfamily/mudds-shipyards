import unittest

from tools.package.source_hash_provenance_v853 import validate_v853


class V853Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v853({"schema_version": 853}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 853",
            validate_v853({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v853({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v853({}), [])


if __name__ == "__main__":
    unittest.main()
