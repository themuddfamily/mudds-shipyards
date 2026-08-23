import unittest

from tools.package.source_hash_provenance_v924 import validate_v924


class V924Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v924({"schema_version": 924}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 924",
            validate_v924({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v924({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v924({}), [])


if __name__ == "__main__":
    unittest.main()
