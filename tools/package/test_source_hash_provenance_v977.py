import unittest

from tools.package.source_hash_provenance_v977 import validate_v977


class V977Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v977({"schema_version": 977}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 977",
            validate_v977({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v977({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v977({}), [])


if __name__ == "__main__":
    unittest.main()
