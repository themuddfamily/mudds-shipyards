import unittest

from tools.package.source_hash_provenance_v997 import validate_v997


class V997Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v997({"schema_version": 997}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 997",
            validate_v997({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v997({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v997({}), [])


if __name__ == "__main__":
    unittest.main()
