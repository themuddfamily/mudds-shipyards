import unittest

from tools.package.source_hash_provenance_v850 import validate_v850


class V850Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v850({"schema_version": 850}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 850",
            validate_v850({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v850({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v850({}), [])


if __name__ == "__main__":
    unittest.main()
