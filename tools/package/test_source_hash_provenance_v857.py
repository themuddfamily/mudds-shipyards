import unittest

from tools.package.source_hash_provenance_v857 import validate_v857


class V857Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v857({"schema_version": 857}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 857",
            validate_v857({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v857({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v857({}), [])


if __name__ == "__main__":
    unittest.main()
