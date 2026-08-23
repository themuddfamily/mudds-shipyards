import unittest

from tools.package.source_hash_provenance_v915 import validate_v915


class V915Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v915({"schema_version": 915}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 915",
            validate_v915({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v915({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v915({}), [])


if __name__ == "__main__":
    unittest.main()
