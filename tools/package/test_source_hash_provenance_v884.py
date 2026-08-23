import unittest

from tools.package.source_hash_provenance_v884 import validate_v884


class V884Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v884({"schema_version": 884}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 884",
            validate_v884({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v884({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v884({}), [])


if __name__ == "__main__":
    unittest.main()
