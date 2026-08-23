import unittest

from tools.package.source_hash_provenance_v809 import validate_v809


class V809Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v809({"schema_version": 809}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 809",
            validate_v809({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v809({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v809({}), [])


if __name__ == "__main__":
    unittest.main()
