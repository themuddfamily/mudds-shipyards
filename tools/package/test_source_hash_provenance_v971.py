import unittest

from tools.package.source_hash_provenance_v971 import validate_v971


class V971Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v971({"schema_version": 971}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 971",
            validate_v971({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v971({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v971({}), [])


if __name__ == "__main__":
    unittest.main()
