import unittest

from tools.package.source_hash_provenance_v932 import validate_v932


class V932Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v932({"schema_version": 932}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 932",
            validate_v932({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v932({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v932({}), [])


if __name__ == "__main__":
    unittest.main()
