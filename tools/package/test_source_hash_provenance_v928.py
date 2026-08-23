import unittest

from tools.package.source_hash_provenance_v928 import validate_v928


class V928Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v928({"schema_version": 928}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 928",
            validate_v928({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v928({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v928({}), [])


if __name__ == "__main__":
    unittest.main()
