import unittest

from tools.package.source_hash_provenance_v1045 import validate_v1045


class V1045Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1045({"schema_version": 1045}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1045",
            validate_v1045({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1045({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1045({}), [])


if __name__ == "__main__":
    unittest.main()
