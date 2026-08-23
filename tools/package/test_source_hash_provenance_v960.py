import unittest

from tools.package.source_hash_provenance_v960 import validate_v960


class V960Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v960({"schema_version": 960}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 960",
            validate_v960({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v960({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v960({}), [])


if __name__ == "__main__":
    unittest.main()
