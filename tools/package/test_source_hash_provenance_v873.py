import unittest

from tools.package.source_hash_provenance_v873 import validate_v873


class V873Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v873({"schema_version": 873}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 873",
            validate_v873({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v873({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v873({}), [])


if __name__ == "__main__":
    unittest.main()
