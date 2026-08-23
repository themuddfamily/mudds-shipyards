import unittest

from tools.package.source_hash_provenance_v1043 import validate_v1043


class V1043Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1043({"schema_version": 1043}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1043",
            validate_v1043({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1043({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1043({}), [])


if __name__ == "__main__":
    unittest.main()
