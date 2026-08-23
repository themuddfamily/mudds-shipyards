import unittest

from tools.package.source_hash_provenance_v851 import validate_v851


class V851Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v851({"schema_version": 851}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 851",
            validate_v851({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v851({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v851({}), [])


if __name__ == "__main__":
    unittest.main()
