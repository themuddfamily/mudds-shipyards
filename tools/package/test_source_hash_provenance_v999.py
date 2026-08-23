import unittest

from tools.package.source_hash_provenance_v999 import validate_v999


class V999Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v999({"schema_version": 999}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 999",
            validate_v999({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v999({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v999({}), [])


if __name__ == "__main__":
    unittest.main()
