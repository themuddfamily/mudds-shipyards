import unittest

from tools.package.source_hash_provenance_v830 import validate_v830


class V830Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v830({"schema_version": 830}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 830",
            validate_v830({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v830({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v830({}), [])


if __name__ == "__main__":
    unittest.main()
