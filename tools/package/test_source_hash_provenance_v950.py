import unittest

from tools.package.source_hash_provenance_v950 import validate_v950


class V950Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v950({"schema_version": 950}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 950",
            validate_v950({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v950({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v950({}), [])


if __name__ == "__main__":
    unittest.main()
