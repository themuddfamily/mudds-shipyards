import unittest

from tools.package.source_hash_provenance_v969 import validate_v969


class V969Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v969({"schema_version": 969}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 969",
            validate_v969({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v969({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v969({}), [])


if __name__ == "__main__":
    unittest.main()
