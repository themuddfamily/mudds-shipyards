import unittest

from tools.package.source_hash_provenance_v938 import validate_v938


class V938Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v938({"schema_version": 938}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 938",
            validate_v938({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v938({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v938({}), [])


if __name__ == "__main__":
    unittest.main()
