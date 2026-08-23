import unittest

from tools.package.source_hash_provenance_v906 import validate_v906


class V906Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v906({"schema_version": 906}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 906",
            validate_v906({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v906({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v906({}), [])


if __name__ == "__main__":
    unittest.main()
