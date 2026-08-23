import unittest

from tools.package.source_hash_provenance_v841 import validate_v841


class V841Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v841({"schema_version": 841}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 841",
            validate_v841({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v841({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v841({}), [])


if __name__ == "__main__":
    unittest.main()
