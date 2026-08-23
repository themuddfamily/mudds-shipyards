import unittest

from tools.package.source_hash_provenance_v944 import validate_v944


class V944Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v944({"schema_version": 944}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 944",
            validate_v944({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v944({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v944({}), [])


if __name__ == "__main__":
    unittest.main()
