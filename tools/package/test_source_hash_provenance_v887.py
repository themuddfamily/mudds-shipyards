import unittest

from tools.package.source_hash_provenance_v887 import validate_v887


class V887Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v887({"schema_version": 887}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 887",
            validate_v887({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v887({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v887({}), [])


if __name__ == "__main__":
    unittest.main()
