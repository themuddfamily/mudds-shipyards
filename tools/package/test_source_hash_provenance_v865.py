import unittest

from tools.package.source_hash_provenance_v865 import validate_v865


class V865Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v865({"schema_version": 865}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 865",
            validate_v865({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v865({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v865({}), [])


if __name__ == "__main__":
    unittest.main()
