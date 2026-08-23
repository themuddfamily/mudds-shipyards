import unittest

from tools.package.source_hash_provenance_v892 import validate_v892


class V892Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v892({"schema_version": 892}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 892",
            validate_v892({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v892({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v892({}), [])


if __name__ == "__main__":
    unittest.main()
