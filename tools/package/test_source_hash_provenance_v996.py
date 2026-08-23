import unittest

from tools.package.source_hash_provenance_v996 import validate_v996


class V996Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v996({"schema_version": 996}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 996",
            validate_v996({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v996({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v996({}), [])


if __name__ == "__main__":
    unittest.main()
