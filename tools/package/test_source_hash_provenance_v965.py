import unittest

from tools.package.source_hash_provenance_v965 import validate_v965


class V965Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v965({"schema_version": 965}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 965",
            validate_v965({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v965({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v965({}), [])


if __name__ == "__main__":
    unittest.main()
