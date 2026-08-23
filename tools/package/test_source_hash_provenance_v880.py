import unittest

from tools.package.source_hash_provenance_v880 import validate_v880


class V880Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v880({"schema_version": 880}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 880",
            validate_v880({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v880({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v880({}), [])


if __name__ == "__main__":
    unittest.main()
