import unittest

from tools.package.source_hash_provenance_v987 import validate_v987


class V987Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v987({"schema_version": 987}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 987",
            validate_v987({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v987({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v987({}), [])


if __name__ == "__main__":
    unittest.main()
