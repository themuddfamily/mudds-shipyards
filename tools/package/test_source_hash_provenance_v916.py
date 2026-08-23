import unittest

from tools.package.source_hash_provenance_v916 import validate_v916


class V916Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v916({"schema_version": 916}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 916",
            validate_v916({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v916({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v916({}), [])


if __name__ == "__main__":
    unittest.main()
