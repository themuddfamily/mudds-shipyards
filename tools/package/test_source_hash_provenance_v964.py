import unittest

from tools.package.source_hash_provenance_v964 import validate_v964


class V964Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v964({"schema_version": 964}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 964",
            validate_v964({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v964({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v964({}), [])


if __name__ == "__main__":
    unittest.main()
