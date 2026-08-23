import unittest

from tools.package.source_hash_provenance_v829 import validate_v829


class V829Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v829({"schema_version": 829}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 829",
            validate_v829({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v829({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v829({}), [])


if __name__ == "__main__":
    unittest.main()
