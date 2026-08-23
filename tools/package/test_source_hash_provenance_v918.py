import unittest

from tools.package.source_hash_provenance_v918 import validate_v918


class V918Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v918({"schema_version": 918}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 918",
            validate_v918({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v918({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v918({}), [])


if __name__ == "__main__":
    unittest.main()
