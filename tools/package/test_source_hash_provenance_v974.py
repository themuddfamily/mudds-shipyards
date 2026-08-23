import unittest

from tools.package.source_hash_provenance_v974 import validate_v974


class V974Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v974({"schema_version": 974}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 974",
            validate_v974({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v974({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v974({}), [])


if __name__ == "__main__":
    unittest.main()
