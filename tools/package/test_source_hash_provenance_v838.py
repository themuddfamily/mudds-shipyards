import unittest

from tools.package.source_hash_provenance_v838 import validate_v838


class V838Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v838({"schema_version": 838}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 838",
            validate_v838({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v838({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v838({}), [])


if __name__ == "__main__":
    unittest.main()
