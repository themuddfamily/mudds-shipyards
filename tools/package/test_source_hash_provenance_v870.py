import unittest

from tools.package.source_hash_provenance_v870 import validate_v870


class V870Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v870({"schema_version": 870}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 870",
            validate_v870({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v870({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v870({}), [])


if __name__ == "__main__":
    unittest.main()
