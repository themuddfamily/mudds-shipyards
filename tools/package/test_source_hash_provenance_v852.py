import unittest

from tools.package.source_hash_provenance_v852 import validate_v852


class V852Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v852({"schema_version": 852}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 852",
            validate_v852({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v852({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v852({}), [])


if __name__ == "__main__":
    unittest.main()
