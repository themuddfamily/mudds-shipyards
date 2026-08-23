import unittest

from tools.package.source_hash_provenance_v980 import validate_v980


class V980Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v980({"schema_version": 980}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 980",
            validate_v980({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v980({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v980({}), [])


if __name__ == "__main__":
    unittest.main()
