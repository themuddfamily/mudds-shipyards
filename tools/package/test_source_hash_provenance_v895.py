import unittest

from tools.package.source_hash_provenance_v895 import validate_v895


class V895Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v895({"schema_version": 895}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 895",
            validate_v895({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v895({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v895({}), [])


if __name__ == "__main__":
    unittest.main()
