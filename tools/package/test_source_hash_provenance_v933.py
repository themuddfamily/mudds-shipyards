import unittest

from tools.package.source_hash_provenance_v933 import validate_v933


class V933Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v933({"schema_version": 933}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 933",
            validate_v933({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v933({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v933({}), [])


if __name__ == "__main__":
    unittest.main()
