import unittest

from tools.package.source_hash_provenance_v979 import validate_v979


class V979Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v979({"schema_version": 979}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 979",
            validate_v979({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v979({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v979({}), [])


if __name__ == "__main__":
    unittest.main()
