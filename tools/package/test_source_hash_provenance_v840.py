import unittest

from tools.package.source_hash_provenance_v840 import validate_v840


class V840Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v840({"schema_version": 840}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 840",
            validate_v840({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v840({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v840({}), [])


if __name__ == "__main__":
    unittest.main()
