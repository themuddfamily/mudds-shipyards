import unittest

from tools.package.source_hash_provenance_v943 import validate_v943


class V943Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v943({"schema_version": 943}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 943",
            validate_v943({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v943({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v943({}), [])


if __name__ == "__main__":
    unittest.main()
