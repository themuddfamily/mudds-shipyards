import unittest

from tools.package.source_hash_provenance_v955 import validate_v955


class V955Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v955({"schema_version": 955}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 955",
            validate_v955({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v955({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v955({}), [])


if __name__ == "__main__":
    unittest.main()
