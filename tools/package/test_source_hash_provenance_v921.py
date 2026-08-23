import unittest

from tools.package.source_hash_provenance_v921 import validate_v921


class V921Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v921({"schema_version": 921}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 921",
            validate_v921({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v921({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v921({}), [])


if __name__ == "__main__":
    unittest.main()
