import unittest

from tools.package.source_hash_provenance_v948 import validate_v948


class V948Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v948({"schema_version": 948}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 948",
            validate_v948({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v948({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v948({}), [])


if __name__ == "__main__":
    unittest.main()
