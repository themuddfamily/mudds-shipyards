import unittest

from tools.package.source_hash_provenance_v839 import validate_v839


class V839Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v839({"schema_version": 839}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 839",
            validate_v839({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v839({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v839({}), [])


if __name__ == "__main__":
    unittest.main()
