import unittest

from tools.package.source_hash_provenance_v1000 import validate_v1000


class V1000Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1000({"schema_version": 1000}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1000",
            validate_v1000({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1000({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1000({}), [])


if __name__ == "__main__":
    unittest.main()
