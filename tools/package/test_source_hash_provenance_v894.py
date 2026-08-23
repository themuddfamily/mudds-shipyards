import unittest

from tools.package.source_hash_provenance_v894 import validate_v894


class V894Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v894({"schema_version": 894}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 894",
            validate_v894({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v894({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v894({}), [])


if __name__ == "__main__":
    unittest.main()
