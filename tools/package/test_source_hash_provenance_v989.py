import unittest

from tools.package.source_hash_provenance_v989 import validate_v989


class V989Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v989({"schema_version": 989}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 989",
            validate_v989({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v989({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v989({}), [])


if __name__ == "__main__":
    unittest.main()
