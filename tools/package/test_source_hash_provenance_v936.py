import unittest

from tools.package.source_hash_provenance_v936 import validate_v936


class V936Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v936({"schema_version": 936}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 936",
            validate_v936({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v936({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v936({}), [])


if __name__ == "__main__":
    unittest.main()
