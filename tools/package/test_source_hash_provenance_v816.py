import unittest

from tools.package.source_hash_provenance_v816 import validate_v816


class V816Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v816({"schema_version": 816}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 816",
            validate_v816({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v816({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v816({}), [])


if __name__ == "__main__":
    unittest.main()
