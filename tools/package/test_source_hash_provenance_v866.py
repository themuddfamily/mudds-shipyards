import unittest

from tools.package.source_hash_provenance_v866 import validate_v866


class V866Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v866({"schema_version": 866}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 866",
            validate_v866({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v866({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v866({}), [])


if __name__ == "__main__":
    unittest.main()
