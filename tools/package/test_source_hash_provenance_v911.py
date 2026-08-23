import unittest

from tools.package.source_hash_provenance_v911 import validate_v911


class V911Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v911({"schema_version": 911}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 911",
            validate_v911({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v911({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v911({}), [])


if __name__ == "__main__":
    unittest.main()
