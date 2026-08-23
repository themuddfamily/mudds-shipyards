import unittest

from tools.package.source_hash_provenance_v988 import validate_v988


class V988Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v988({"schema_version": 988}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 988",
            validate_v988({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v988({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v988({}), [])


if __name__ == "__main__":
    unittest.main()
