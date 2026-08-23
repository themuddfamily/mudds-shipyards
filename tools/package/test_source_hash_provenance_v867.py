import unittest

from tools.package.source_hash_provenance_v867 import validate_v867


class V867Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v867({"schema_version": 867}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 867",
            validate_v867({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v867({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v867({}), [])


if __name__ == "__main__":
    unittest.main()
