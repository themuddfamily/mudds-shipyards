import unittest

from tools.package.source_hash_provenance_v961 import validate_v961


class V961Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v961({"schema_version": 961}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 961",
            validate_v961({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v961({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v961({}), [])


if __name__ == "__main__":
    unittest.main()
