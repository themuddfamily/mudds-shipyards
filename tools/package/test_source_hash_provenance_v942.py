import unittest

from tools.package.source_hash_provenance_v942 import validate_v942


class V942Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v942({"schema_version": 942}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 942",
            validate_v942({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v942({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v942({}), [])


if __name__ == "__main__":
    unittest.main()
