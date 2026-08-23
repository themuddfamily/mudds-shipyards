import unittest

from tools.package.source_hash_provenance_v991 import validate_v991


class V991Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v991({"schema_version": 991}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 991",
            validate_v991({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v991({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v991({}), [])


if __name__ == "__main__":
    unittest.main()
