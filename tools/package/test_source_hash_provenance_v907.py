import unittest

from tools.package.source_hash_provenance_v907 import validate_v907


class V907Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v907({"schema_version": 907}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 907",
            validate_v907({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v907({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v907({}), [])


if __name__ == "__main__":
    unittest.main()
