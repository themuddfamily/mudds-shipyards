import unittest

from tools.package.source_hash_provenance_v909 import validate_v909


class V909Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v909({"schema_version": 909}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 909",
            validate_v909({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v909({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v909({}), [])


if __name__ == "__main__":
    unittest.main()
