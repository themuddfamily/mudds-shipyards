import unittest

from tools.package.source_hash_provenance_v898 import validate_v898


class V898Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v898({"schema_version": 898}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 898",
            validate_v898({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v898({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v898({}), [])


if __name__ == "__main__":
    unittest.main()
