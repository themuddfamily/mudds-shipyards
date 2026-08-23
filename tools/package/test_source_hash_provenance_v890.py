import unittest

from tools.package.source_hash_provenance_v890 import validate_v890


class V890Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v890({"schema_version": 890}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 890",
            validate_v890({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v890({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v890({}), [])


if __name__ == "__main__":
    unittest.main()
