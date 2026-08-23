import unittest

from tools.package.source_hash_provenance_v817 import validate_v817


class V817Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v817({"schema_version": 817}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 817",
            validate_v817({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v817({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v817({}), [])


if __name__ == "__main__":
    unittest.main()
