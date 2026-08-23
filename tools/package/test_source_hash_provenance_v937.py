import unittest

from tools.package.source_hash_provenance_v937 import validate_v937


class V937Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v937({"schema_version": 937}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 937",
            validate_v937({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v937({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v937({}), [])


if __name__ == "__main__":
    unittest.main()
