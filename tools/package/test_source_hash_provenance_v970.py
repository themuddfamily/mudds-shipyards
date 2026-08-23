import unittest

from tools.package.source_hash_provenance_v970 import validate_v970


class V970Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v970({"schema_version": 970}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 970",
            validate_v970({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v970({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v970({}), [])


if __name__ == "__main__":
    unittest.main()
