import unittest

from tools.package.source_hash_provenance_v875 import validate_v875


class V875Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v875({"schema_version": 875}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 875",
            validate_v875({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v875({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v875({}), [])


if __name__ == "__main__":
    unittest.main()
