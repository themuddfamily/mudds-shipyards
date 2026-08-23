import unittest

from tools.package.source_hash_provenance_v819 import validate_v819


class V819Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v819({"schema_version": 819}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 819",
            validate_v819({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v819({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v819({}), [])


if __name__ == "__main__":
    unittest.main()
