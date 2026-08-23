import unittest

from tools.package.source_hash_provenance_v811 import validate_v811


class V811Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v811({"schema_version": 811}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 811",
            validate_v811({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v811({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v811({}), [])


if __name__ == "__main__":
    unittest.main()
