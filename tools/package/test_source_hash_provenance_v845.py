import unittest

from tools.package.source_hash_provenance_v845 import validate_v845


class V845Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v845({"schema_version": 845}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 845",
            validate_v845({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v845({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v845({}), [])


if __name__ == "__main__":
    unittest.main()
