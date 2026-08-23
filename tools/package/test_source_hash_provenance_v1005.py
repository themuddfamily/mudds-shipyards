import unittest

from tools.package.source_hash_provenance_v1005 import validate_v1005


class V1005Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1005({"schema_version": 1005}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1005",
            validate_v1005({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1005({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1005({}), [])


if __name__ == "__main__":
    unittest.main()
