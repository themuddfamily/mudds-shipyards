import unittest

from tools.package.source_hash_provenance_v983 import validate_v983


class V983Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v983({"schema_version": 983}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 983",
            validate_v983({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v983({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v983({}), [])


if __name__ == "__main__":
    unittest.main()
