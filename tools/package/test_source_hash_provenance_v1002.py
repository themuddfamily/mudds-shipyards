import unittest

from tools.package.source_hash_provenance_v1002 import validate_v1002


class V1002Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1002({"schema_version": 1002}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1002",
            validate_v1002({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1002({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1002({}), [])


if __name__ == "__main__":
    unittest.main()
