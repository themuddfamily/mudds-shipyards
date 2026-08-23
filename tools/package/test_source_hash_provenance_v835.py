import unittest

from tools.package.source_hash_provenance_v835 import validate_v835


class V835Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v835({"schema_version": 835}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 835",
            validate_v835({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v835({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v835({}), [])


if __name__ == "__main__":
    unittest.main()
