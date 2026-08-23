import unittest

from tools.package.source_hash_provenance_v831 import validate_v831


class V831Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v831({"schema_version": 831}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 831",
            validate_v831({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v831({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v831({}), [])


if __name__ == "__main__":
    unittest.main()
