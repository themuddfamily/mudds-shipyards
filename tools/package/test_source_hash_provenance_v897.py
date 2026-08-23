import unittest

from tools.package.source_hash_provenance_v897 import validate_v897


class V897Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v897({"schema_version": 897}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 897",
            validate_v897({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v897({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v897({}), [])


if __name__ == "__main__":
    unittest.main()
