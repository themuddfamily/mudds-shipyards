import unittest

from tools.package.source_hash_provenance_v808 import validate_v808


class V808Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v808({"schema_version": 808}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 808",
            validate_v808({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v808({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v808({}), [])


if __name__ == "__main__":
    unittest.main()
