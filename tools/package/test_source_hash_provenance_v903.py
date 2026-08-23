import unittest

from tools.package.source_hash_provenance_v903 import validate_v903


class V903Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v903({"schema_version": 903}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 903",
            validate_v903({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v903({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v903({}), [])


if __name__ == "__main__":
    unittest.main()
