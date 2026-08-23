import unittest

from tools.package.source_hash_provenance_v954 import validate_v954


class V954Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v954({"schema_version": 954}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 954",
            validate_v954({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v954({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v954({}), [])


if __name__ == "__main__":
    unittest.main()
