import unittest

from tools.package.source_hash_provenance_v949 import validate_v949


class V949Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v949({"schema_version": 949}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 949",
            validate_v949({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v949({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v949({}), [])


if __name__ == "__main__":
    unittest.main()
