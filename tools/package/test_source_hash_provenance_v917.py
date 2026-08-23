import unittest

from tools.package.source_hash_provenance_v917 import validate_v917


class V917Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v917({"schema_version": 917}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 917",
            validate_v917({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v917({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v917({}), [])


if __name__ == "__main__":
    unittest.main()
