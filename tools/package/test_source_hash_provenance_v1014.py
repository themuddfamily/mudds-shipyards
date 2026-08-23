import unittest

from tools.package.source_hash_provenance_v1014 import validate_v1014


class V1014Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1014({"schema_version": 1014}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1014",
            validate_v1014({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1014({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1014({}), [])


if __name__ == "__main__":
    unittest.main()
