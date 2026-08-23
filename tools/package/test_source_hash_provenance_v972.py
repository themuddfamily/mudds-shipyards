import unittest

from tools.package.source_hash_provenance_v972 import validate_v972


class V972Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v972({"schema_version": 972}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 972",
            validate_v972({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v972({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v972({}), [])


if __name__ == "__main__":
    unittest.main()
