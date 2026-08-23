import unittest

from tools.package.source_hash_provenance_v994 import validate_v994


class V994Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v994({"schema_version": 994}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 994",
            validate_v994({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v994({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v994({}), [])


if __name__ == "__main__":
    unittest.main()
