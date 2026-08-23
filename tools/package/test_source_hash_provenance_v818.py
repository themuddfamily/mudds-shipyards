import unittest

from tools.package.source_hash_provenance_v818 import validate_v818


class V818Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v818({"schema_version": 818}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 818",
            validate_v818({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v818({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v818({}), [])


if __name__ == "__main__":
    unittest.main()
