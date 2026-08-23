import unittest

from tools.package.source_hash_provenance_v1019 import validate_v1019


class V1019Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1019({"schema_version": 1019}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1019",
            validate_v1019({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1019({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1019({}), [])


if __name__ == "__main__":
    unittest.main()
