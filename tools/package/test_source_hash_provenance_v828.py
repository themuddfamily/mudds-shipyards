import unittest

from tools.package.source_hash_provenance_v828 import validate_v828


class V828Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v828({"schema_version": 828}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 828",
            validate_v828({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v828({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v828({}), [])


if __name__ == "__main__":
    unittest.main()
