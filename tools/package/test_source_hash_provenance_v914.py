import unittest

from tools.package.source_hash_provenance_v914 import validate_v914


class V914Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v914({"schema_version": 914}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 914",
            validate_v914({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v914({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v914({}), [])


if __name__ == "__main__":
    unittest.main()
