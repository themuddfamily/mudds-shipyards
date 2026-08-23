import unittest

from tools.package.source_hash_provenance_v1009 import validate_v1009


class V1009Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1009({"schema_version": 1009}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1009",
            validate_v1009({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1009({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1009({}), [])


if __name__ == "__main__":
    unittest.main()
