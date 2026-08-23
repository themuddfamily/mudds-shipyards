import unittest

from tools.package.source_hash_provenance_v856 import validate_v856


class V856Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v856({"schema_version": 856}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 856",
            validate_v856({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v856({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v856({}), [])


if __name__ == "__main__":
    unittest.main()
