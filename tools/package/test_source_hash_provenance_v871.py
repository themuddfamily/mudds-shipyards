import unittest

from tools.package.source_hash_provenance_v871 import validate_v871


class V871Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v871({"schema_version": 871}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 871",
            validate_v871({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v871({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v871({}), [])


if __name__ == "__main__":
    unittest.main()
