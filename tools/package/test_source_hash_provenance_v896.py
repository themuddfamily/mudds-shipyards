import unittest

from tools.package.source_hash_provenance_v896 import validate_v896


class V896Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v896({"schema_version": 896}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 896",
            validate_v896({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v896({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v896({}), [])


if __name__ == "__main__":
    unittest.main()
