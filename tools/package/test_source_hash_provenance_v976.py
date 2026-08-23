import unittest

from tools.package.source_hash_provenance_v976 import validate_v976


class V976Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v976({"schema_version": 976}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 976",
            validate_v976({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v976({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v976({}), [])


if __name__ == "__main__":
    unittest.main()
