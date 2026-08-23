import unittest

from tools.package.source_hash_provenance_v978 import validate_v978


class V978Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v978({"schema_version": 978}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 978",
            validate_v978({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v978({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v978({}), [])


if __name__ == "__main__":
    unittest.main()
