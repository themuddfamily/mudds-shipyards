import unittest

from tools.package.source_hash_provenance_v834 import validate_v834


class V834Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v834({"schema_version": 834}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 834",
            validate_v834({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v834({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v834({}), [])


if __name__ == "__main__":
    unittest.main()
