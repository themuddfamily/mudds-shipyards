import unittest

from tools.package.source_hash_provenance_v963 import validate_v963


class V963Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v963({"schema_version": 963}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 963",
            validate_v963({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v963({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v963({}), [])


if __name__ == "__main__":
    unittest.main()
