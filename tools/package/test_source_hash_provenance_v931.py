import unittest

from tools.package.source_hash_provenance_v931 import validate_v931


class V931Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v931({"schema_version": 931}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 931",
            validate_v931({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v931({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v931({}), [])


if __name__ == "__main__":
    unittest.main()
