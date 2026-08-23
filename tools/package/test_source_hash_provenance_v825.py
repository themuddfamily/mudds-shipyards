import unittest

from tools.package.source_hash_provenance_v825 import validate_v825


class V825Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v825({"schema_version": 825}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 825",
            validate_v825({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v825({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v825({}), [])


if __name__ == "__main__":
    unittest.main()
