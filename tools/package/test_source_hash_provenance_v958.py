import unittest

from tools.package.source_hash_provenance_v958 import validate_v958


class V958Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v958({"schema_version": 958}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 958",
            validate_v958({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v958({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v958({}), [])


if __name__ == "__main__":
    unittest.main()
