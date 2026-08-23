import unittest

from tools.package.source_hash_provenance_v992 import validate_v992


class V992Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v992({"schema_version": 992}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 992",
            validate_v992({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v992({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v992({}), [])


if __name__ == "__main__":
    unittest.main()
