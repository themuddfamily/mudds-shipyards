import unittest

from tools.package.source_hash_provenance_v863 import validate_v863


class V863Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v863({"schema_version": 863}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 863",
            validate_v863({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v863({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v863({}), [])


if __name__ == "__main__":
    unittest.main()
