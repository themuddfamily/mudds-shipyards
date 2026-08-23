import unittest

from tools.package.source_hash_provenance_v876 import validate_v876


class V876Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v876({"schema_version": 876}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 876",
            validate_v876({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v876({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v876({}), [])


if __name__ == "__main__":
    unittest.main()
