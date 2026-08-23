import unittest

from tools.package.source_hash_provenance_v952 import validate_v952


class V952Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v952({"schema_version": 952}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 952",
            validate_v952({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v952({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v952({}), [])


if __name__ == "__main__":
    unittest.main()
