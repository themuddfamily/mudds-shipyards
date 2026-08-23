import unittest

from tools.package.source_hash_provenance_v1033 import validate_v1033


class V1033Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1033({"schema_version": 1033}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1033",
            validate_v1033({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1033({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1033({}), [])


if __name__ == "__main__":
    unittest.main()
