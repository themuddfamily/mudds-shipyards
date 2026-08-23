import unittest

from tools.package.source_hash_provenance_v889 import validate_v889


class V889Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v889({"schema_version": 889}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 889",
            validate_v889({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v889({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v889({}), [])


if __name__ == "__main__":
    unittest.main()
