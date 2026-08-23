import unittest

from tools.package.source_hash_provenance_v982 import validate_v982


class V982Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v982({"schema_version": 982}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 982",
            validate_v982({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v982({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v982({}), [])


if __name__ == "__main__":
    unittest.main()
