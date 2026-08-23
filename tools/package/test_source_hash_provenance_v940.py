import unittest

from tools.package.source_hash_provenance_v940 import validate_v940


class V940Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v940({"schema_version": 940}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 940",
            validate_v940({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v940({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v940({}), [])


if __name__ == "__main__":
    unittest.main()
