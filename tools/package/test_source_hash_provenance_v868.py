import unittest

from tools.package.source_hash_provenance_v868 import validate_v868


class V868Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v868({"schema_version": 868}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 868",
            validate_v868({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v868({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v868({}), [])


if __name__ == "__main__":
    unittest.main()
