import unittest

from tools.package.source_hash_provenance_v990 import validate_v990


class V990Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v990({"schema_version": 990}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 990",
            validate_v990({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v990({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v990({}), [])


if __name__ == "__main__":
    unittest.main()
