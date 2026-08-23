import unittest

from tools.package.source_hash_provenance_v930 import validate_v930


class V930Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v930({"schema_version": 930}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 930",
            validate_v930({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v930({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v930({}), [])


if __name__ == "__main__":
    unittest.main()
