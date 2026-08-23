import unittest

from tools.package.source_hash_provenance_v985 import validate_v985


class V985Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v985({"schema_version": 985}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 985",
            validate_v985({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v985({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v985({}), [])


if __name__ == "__main__":
    unittest.main()
