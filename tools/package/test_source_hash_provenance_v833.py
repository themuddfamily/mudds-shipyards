import unittest

from tools.package.source_hash_provenance_v833 import validate_v833


class V833Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v833({"schema_version": 833}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 833",
            validate_v833({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v833({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v833({}), [])


if __name__ == "__main__":
    unittest.main()
