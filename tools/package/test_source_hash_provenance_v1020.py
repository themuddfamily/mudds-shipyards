import unittest

from tools.package.source_hash_provenance_v1020 import validate_v1020


class V1020Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1020({"schema_version": 1020}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1020",
            validate_v1020({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1020({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1020({}), [])


if __name__ == "__main__":
    unittest.main()
