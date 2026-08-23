import unittest

from tools.package.source_hash_provenance_v900 import validate_v900


class V900Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v900({"schema_version": 900}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 900",
            validate_v900({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v900({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v900({}), [])


if __name__ == "__main__":
    unittest.main()
