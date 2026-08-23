import unittest

from tools.package.source_hash_provenance_v966 import validate_v966


class V966Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v966({"schema_version": 966}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 966",
            validate_v966({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v966({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v966({}), [])


if __name__ == "__main__":
    unittest.main()
