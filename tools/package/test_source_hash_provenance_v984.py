import unittest

from tools.package.source_hash_provenance_v984 import validate_v984


class V984Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v984({"schema_version": 984}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 984",
            validate_v984({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v984({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v984({}), [])


if __name__ == "__main__":
    unittest.main()
