import unittest

from tools.package.source_hash_provenance_v837 import validate_v837


class V837Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v837({"schema_version": 837}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 837",
            validate_v837({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v837({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v837({}), [])


if __name__ == "__main__":
    unittest.main()
