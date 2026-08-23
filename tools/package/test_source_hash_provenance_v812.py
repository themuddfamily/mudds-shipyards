import unittest

from tools.package.source_hash_provenance_v812 import validate_v812


class V812Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v812({"schema_version": 812}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 812",
            validate_v812({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v812({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v812({}), [])


if __name__ == "__main__":
    unittest.main()
