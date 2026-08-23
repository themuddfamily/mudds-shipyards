import unittest

from tools.package.source_hash_provenance_v843 import validate_v843


class V843Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v843({"schema_version": 843}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 843",
            validate_v843({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v843({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v843({}), [])


if __name__ == "__main__":
    unittest.main()
