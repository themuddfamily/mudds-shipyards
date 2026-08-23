import unittest

from tools.package.source_hash_provenance_v939 import validate_v939


class V939Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v939({"schema_version": 939}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 939",
            validate_v939({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v939({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v939({}), [])


if __name__ == "__main__":
    unittest.main()
