import unittest

from tools.package.source_hash_provenance_v813 import validate_v813


class V813Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v813({"schema_version": 813}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 813",
            validate_v813({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v813({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v813({}), [])


if __name__ == "__main__":
    unittest.main()
