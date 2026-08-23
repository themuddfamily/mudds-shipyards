import unittest

from tools.package.source_hash_provenance_v854 import validate_v854


class V854Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v854({"schema_version": 854}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 854",
            validate_v854({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v854({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v854({}), [])


if __name__ == "__main__":
    unittest.main()
