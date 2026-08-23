import unittest

from tools.package.source_hash_provenance_v929 import validate_v929


class V929Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v929({"schema_version": 929}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 929",
            validate_v929({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v929({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v929({}), [])


if __name__ == "__main__":
    unittest.main()
