import unittest

from tools.package.source_hash_provenance_v1011 import validate_v1011


class V1011Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1011({"schema_version": 1011}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1011",
            validate_v1011({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1011({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1011({}), [])


if __name__ == "__main__":
    unittest.main()
