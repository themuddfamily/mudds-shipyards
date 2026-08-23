import unittest

from tools.package.source_hash_provenance_v846 import validate_v846


class V846Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v846({"schema_version": 846}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 846",
            validate_v846({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v846({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v846({}), [])


if __name__ == "__main__":
    unittest.main()
