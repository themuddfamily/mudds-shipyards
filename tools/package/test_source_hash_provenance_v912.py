import unittest

from tools.package.source_hash_provenance_v912 import validate_v912


class V912Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v912({"schema_version": 912}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 912",
            validate_v912({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v912({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v912({}), [])


if __name__ == "__main__":
    unittest.main()
