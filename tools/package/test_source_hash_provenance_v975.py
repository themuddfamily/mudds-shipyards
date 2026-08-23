import unittest

from tools.package.source_hash_provenance_v975 import validate_v975


class V975Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v975({"schema_version": 975}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 975",
            validate_v975({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v975({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v975({}), [])


if __name__ == "__main__":
    unittest.main()
