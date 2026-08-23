import unittest

from tools.package.source_hash_provenance_v956 import validate_v956


class V956Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v956({"schema_version": 956}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 956",
            validate_v956({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v956({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v956({}), [])


if __name__ == "__main__":
    unittest.main()
