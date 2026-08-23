import unittest

from tools.package.source_hash_provenance_v922 import validate_v922


class V922Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v922({"schema_version": 922}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 922",
            validate_v922({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v922({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v922({}), [])


if __name__ == "__main__":
    unittest.main()
