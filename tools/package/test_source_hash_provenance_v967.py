import unittest

from tools.package.source_hash_provenance_v967 import validate_v967


class V967Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v967({"schema_version": 967}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 967",
            validate_v967({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v967({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v967({}), [])


if __name__ == "__main__":
    unittest.main()
