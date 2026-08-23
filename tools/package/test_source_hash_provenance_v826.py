import unittest

from tools.package.source_hash_provenance_v826 import validate_v826


class V826Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v826({"schema_version": 826}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 826",
            validate_v826({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v826({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v826({}), [])


if __name__ == "__main__":
    unittest.main()
