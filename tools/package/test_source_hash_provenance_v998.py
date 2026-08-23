import unittest

from tools.package.source_hash_provenance_v998 import validate_v998


class V998Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v998({"schema_version": 998}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 998",
            validate_v998({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v998({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v998({}), [])


if __name__ == "__main__":
    unittest.main()
