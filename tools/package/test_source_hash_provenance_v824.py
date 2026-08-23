import unittest

from tools.package.source_hash_provenance_v824 import validate_v824


class V824Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v824({"schema_version": 824}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 824",
            validate_v824({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v824({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v824({}), [])


if __name__ == "__main__":
    unittest.main()
