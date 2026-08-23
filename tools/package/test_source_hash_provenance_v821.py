import unittest

from tools.package.source_hash_provenance_v821 import validate_v821


class V821Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v821({"schema_version": 821}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 821",
            validate_v821({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v821({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v821({}), [])


if __name__ == "__main__":
    unittest.main()
