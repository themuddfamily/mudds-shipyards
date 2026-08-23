import unittest

from tools.package.source_hash_provenance_v993 import validate_v993


class V993Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v993({"schema_version": 993}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 993",
            validate_v993({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v993({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v993({}), [])


if __name__ == "__main__":
    unittest.main()
