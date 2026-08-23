import unittest

from tools.package.source_hash_provenance_v893 import validate_v893


class V893Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v893({"schema_version": 893}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 893",
            validate_v893({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v893({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v893({}), [])


if __name__ == "__main__":
    unittest.main()
