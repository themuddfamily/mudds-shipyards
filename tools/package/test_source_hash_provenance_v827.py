import unittest

from tools.package.source_hash_provenance_v827 import validate_v827


class V827Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v827({"schema_version": 827}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 827",
            validate_v827({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v827({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v827({}), [])


if __name__ == "__main__":
    unittest.main()
