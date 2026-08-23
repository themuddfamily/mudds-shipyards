import unittest

from tools.package.source_hash_provenance_v902 import validate_v902


class V902Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v902({"schema_version": 902}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 902",
            validate_v902({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v902({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v902({}), [])


if __name__ == "__main__":
    unittest.main()
