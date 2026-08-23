import unittest

from tools.package.source_hash_provenance_v945 import validate_v945


class V945Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v945({"schema_version": 945}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 945",
            validate_v945({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v945({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v945({}), [])


if __name__ == "__main__":
    unittest.main()
