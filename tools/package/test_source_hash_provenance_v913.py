import unittest

from tools.package.source_hash_provenance_v913 import validate_v913


class V913Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v913({"schema_version": 913}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 913",
            validate_v913({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v913({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v913({}), [])


if __name__ == "__main__":
    unittest.main()
