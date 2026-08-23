import unittest

from tools.package.source_hash_provenance_v905 import validate_v905


class V905Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v905({"schema_version": 905}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 905",
            validate_v905({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v905({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v905({}), [])


if __name__ == "__main__":
    unittest.main()
