import unittest

from tools.package.source_hash_provenance_v925 import validate_v925


class V925Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v925({"schema_version": 925}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 925",
            validate_v925({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v925({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v925({}), [])


if __name__ == "__main__":
    unittest.main()
