import unittest

from tools.package.source_hash_provenance_v934 import validate_v934


class V934Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v934({"schema_version": 934}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 934",
            validate_v934({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v934({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v934({}), [])


if __name__ == "__main__":
    unittest.main()
