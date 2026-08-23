import unittest

from tools.package.source_hash_provenance_v820 import validate_v820


class V820Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v820({"schema_version": 820}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 820",
            validate_v820({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v820({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v820({}), [])


if __name__ == "__main__":
    unittest.main()
