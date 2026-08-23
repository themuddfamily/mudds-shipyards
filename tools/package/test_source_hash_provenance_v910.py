import unittest

from tools.package.source_hash_provenance_v910 import validate_v910


class V910Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v910({"schema_version": 910}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 910",
            validate_v910({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v910({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v910({}), [])


if __name__ == "__main__":
    unittest.main()
