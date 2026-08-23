import unittest

from tools.package.source_hash_provenance_v981 import validate_v981


class V981Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v981({"schema_version": 981}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 981",
            validate_v981({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v981({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v981({}), [])


if __name__ == "__main__":
    unittest.main()
