import unittest

from tools.package.source_hash_provenance_v861 import validate_v861


class V861Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v861({"schema_version": 861}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 861",
            validate_v861({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v861({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v861({}), [])


if __name__ == "__main__":
    unittest.main()
