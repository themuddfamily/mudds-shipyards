import unittest

from tools.package.source_hash_provenance_v888 import validate_v888


class V888Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v888({"schema_version": 888}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 888",
            validate_v888({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v888({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v888({}), [])


if __name__ == "__main__":
    unittest.main()
