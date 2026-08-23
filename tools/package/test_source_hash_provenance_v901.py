import unittest

from tools.package.source_hash_provenance_v901 import validate_v901


class V901Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v901({"schema_version": 901}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 901",
            validate_v901({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v901({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v901({}), [])


if __name__ == "__main__":
    unittest.main()
