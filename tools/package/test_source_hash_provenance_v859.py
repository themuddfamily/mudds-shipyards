import unittest

from tools.package.source_hash_provenance_v859 import validate_v859


class V859Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v859({"schema_version": 859}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 859",
            validate_v859({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v859({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v859({}), [])


if __name__ == "__main__":
    unittest.main()
