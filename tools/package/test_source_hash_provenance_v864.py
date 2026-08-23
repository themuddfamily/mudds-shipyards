import unittest

from tools.package.source_hash_provenance_v864 import validate_v864


class V864Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v864({"schema_version": 864}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 864",
            validate_v864({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v864({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v864({}), [])


if __name__ == "__main__":
    unittest.main()
