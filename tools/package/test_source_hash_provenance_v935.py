import unittest

from tools.package.source_hash_provenance_v935 import validate_v935


class V935Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v935({"schema_version": 935}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 935",
            validate_v935({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v935({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v935({}), [])


if __name__ == "__main__":
    unittest.main()
