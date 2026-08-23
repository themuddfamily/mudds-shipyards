import unittest

from tools.package.source_hash_provenance_v862 import validate_v862


class V862Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v862({"schema_version": 862}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 862",
            validate_v862({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v862({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v862({}), [])


if __name__ == "__main__":
    unittest.main()
