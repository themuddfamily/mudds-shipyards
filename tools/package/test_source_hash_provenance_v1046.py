import unittest

from tools.package.source_hash_provenance_v1046 import validate_v1046


class V1046Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v1046({"schema_version": 1046}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 1046",
            validate_v1046({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v1046({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v1046({}), [])


if __name__ == "__main__":
    unittest.main()
