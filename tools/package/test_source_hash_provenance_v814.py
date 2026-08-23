import unittest

from tools.package.source_hash_provenance_v814 import validate_v814


class V814Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v814({"schema_version": 814}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 814",
            validate_v814({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v814({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v814({}), [])


if __name__ == "__main__":
    unittest.main()
