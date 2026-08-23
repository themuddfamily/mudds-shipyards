import unittest

from tools.package.source_hash_provenance_v904 import validate_v904


class V904Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v904({"schema_version": 904}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 904",
            validate_v904({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v904({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v904({}), [])


if __name__ == "__main__":
    unittest.main()
