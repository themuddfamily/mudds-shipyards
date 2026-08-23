import unittest

from tools.package.source_hash_provenance_v858 import validate_v858


class V858Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v858({"schema_version": 858}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 858",
            validate_v858({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v858({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v858({}), [])


if __name__ == "__main__":
    unittest.main()
