import unittest

from tools.package.source_hash_provenance_v923 import validate_v923


class V923Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v923({"schema_version": 923}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 923",
            validate_v923({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v923({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v923({}), [])


if __name__ == "__main__":
    unittest.main()
