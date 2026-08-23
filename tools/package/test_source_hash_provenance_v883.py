import unittest

from tools.package.source_hash_provenance_v883 import validate_v883


class V883Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v883({"schema_version": 883}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 883",
            validate_v883({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v883({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v883({}), [])


if __name__ == "__main__":
    unittest.main()
