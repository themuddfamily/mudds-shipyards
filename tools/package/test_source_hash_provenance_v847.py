import unittest

from tools.package.source_hash_provenance_v847 import validate_v847


class V847Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v847({"schema_version": 847}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 847",
            validate_v847({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v847({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v847({}), [])


if __name__ == "__main__":
    unittest.main()
