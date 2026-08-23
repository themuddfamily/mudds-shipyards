import unittest

from tools.package.source_hash_provenance_v995 import validate_v995


class V995Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v995({"schema_version": 995}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 995",
            validate_v995({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v995({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v995({}), [])


if __name__ == "__main__":
    unittest.main()
