import unittest

from tools.package.source_hash_provenance_v920 import validate_v920


class V920Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v920({"schema_version": 920}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 920",
            validate_v920({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v920({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v920({}), [])


if __name__ == "__main__":
    unittest.main()
