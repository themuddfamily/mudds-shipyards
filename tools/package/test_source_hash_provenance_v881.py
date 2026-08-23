import unittest

from tools.package.source_hash_provenance_v881 import validate_v881


class V881Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v881({"schema_version": 881}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 881",
            validate_v881({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v881({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v881({}), [])


if __name__ == "__main__":
    unittest.main()
