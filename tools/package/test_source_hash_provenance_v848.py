import unittest

from tools.package.source_hash_provenance_v848 import validate_v848


class V848Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v848({"schema_version": 848}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 848",
            validate_v848({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v848({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v848({}), [])


if __name__ == "__main__":
    unittest.main()
