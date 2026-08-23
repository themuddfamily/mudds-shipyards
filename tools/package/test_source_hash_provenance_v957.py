import unittest

from tools.package.source_hash_provenance_v957 import validate_v957


class V957Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v957({"schema_version": 957}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 957",
            validate_v957({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v957({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v957({}), [])


if __name__ == "__main__":
    unittest.main()
