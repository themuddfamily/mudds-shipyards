import unittest

from tools.package.source_hash_provenance_v1029 import validate_v1029


class V1029Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1029({"schema_version": 1029}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1029",
            validate_v1029({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1029({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1029({}), [])


if __name__ == "__main__":
    unittest.main()
