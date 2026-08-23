import unittest

from tools.package.source_hash_provenance_v941 import validate_v941


class V941Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v941({"schema_version": 941}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 941",
            validate_v941({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v941({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v941({}), [])


if __name__ == "__main__":
    unittest.main()
