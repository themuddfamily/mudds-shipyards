import unittest

from tools.package.source_hash_provenance_v836 import validate_v836


class V836Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v836({"schema_version": 836}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 836",
            validate_v836({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v836({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v836({}), [])


if __name__ == "__main__":
    unittest.main()
