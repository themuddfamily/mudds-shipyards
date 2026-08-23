import unittest

from tools.package.source_hash_provenance_v849 import validate_v849


class V849Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v849({"schema_version": 849}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 849",
            validate_v849({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v849({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v849({}), [])


if __name__ == "__main__":
    unittest.main()
