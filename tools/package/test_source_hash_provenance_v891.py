import unittest

from tools.package.source_hash_provenance_v891 import validate_v891


class V891Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v891({"schema_version": 891}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 891",
            validate_v891({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v891({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v891({}), [])


if __name__ == "__main__":
    unittest.main()
