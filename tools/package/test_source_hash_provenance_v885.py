import unittest

from tools.package.source_hash_provenance_v885 import validate_v885


class V885Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v885({"schema_version": 885}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 885",
            validate_v885({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v885({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v885({}), [])


if __name__ == "__main__":
    unittest.main()
