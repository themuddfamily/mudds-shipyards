import unittest

from tools.package.source_hash_provenance_v832 import validate_v832


class V832Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v832({"schema_version": 832}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 832",
            validate_v832({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v832({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v832({}), [])


if __name__ == "__main__":
    unittest.main()
