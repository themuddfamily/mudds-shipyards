import unittest

from tools.package.source_hash_provenance_v1037 import validate_v1037


class V1037Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1037({"schema_version": 1037}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1037",
            validate_v1037({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1037({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1037({}), [])


if __name__ == "__main__":
    unittest.main()
