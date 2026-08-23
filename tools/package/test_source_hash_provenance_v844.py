import unittest

from tools.package.source_hash_provenance_v844 import validate_v844


class V844Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v844({"schema_version": 844}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 844",
            validate_v844({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v844({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v844({}), [])


if __name__ == "__main__":
    unittest.main()
