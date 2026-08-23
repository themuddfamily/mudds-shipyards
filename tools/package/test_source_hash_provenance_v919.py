import unittest

from tools.package.source_hash_provenance_v919 import validate_v919


class V919Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v919({"schema_version": 919}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 919",
            validate_v919({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v919({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v919({}), [])


if __name__ == "__main__":
    unittest.main()
