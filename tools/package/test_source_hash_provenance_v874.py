import unittest

from tools.package.source_hash_provenance_v874 import validate_v874


class V874Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v874({"schema_version": 874}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 874",
            validate_v874({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v874({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v874({}), [])


if __name__ == "__main__":
    unittest.main()
