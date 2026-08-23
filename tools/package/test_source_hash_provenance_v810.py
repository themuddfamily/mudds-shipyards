import unittest

from tools.package.source_hash_provenance_v810 import validate_v810


class V810Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v810({"schema_version": 810}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 810",
            validate_v810({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v810({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v810({}), [])


if __name__ == "__main__":
    unittest.main()
