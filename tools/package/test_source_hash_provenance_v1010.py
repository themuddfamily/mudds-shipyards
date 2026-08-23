import unittest

from tools.package.source_hash_provenance_v1010 import validate_v1010


class V1010Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1010({"schema_version": 1010}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1010",
            validate_v1010({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1010({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1010({}), [])


if __name__ == "__main__":
    unittest.main()
