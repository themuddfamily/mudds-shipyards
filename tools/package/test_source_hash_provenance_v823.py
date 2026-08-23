import unittest

from tools.package.source_hash_provenance_v823 import validate_v823


class V823Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v823({"schema_version": 823}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 823",
            validate_v823({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v823({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v823({}), [])


if __name__ == "__main__":
    unittest.main()
