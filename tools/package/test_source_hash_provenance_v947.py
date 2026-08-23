import unittest

from tools.package.source_hash_provenance_v947 import validate_v947


class V947Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v947({"schema_version": 947}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 947",
            validate_v947({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v947({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v947({}), [])


if __name__ == "__main__":
    unittest.main()
