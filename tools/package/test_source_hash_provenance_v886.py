import unittest

from tools.package.source_hash_provenance_v886 import validate_v886


class V886Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v886({"schema_version": 886}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 886",
            validate_v886({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v886({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v886({}), [])


if __name__ == "__main__":
    unittest.main()
