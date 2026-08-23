import unittest

from tools.package.source_hash_provenance_v959 import validate_v959


class V959Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v959({"schema_version": 959}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 959",
            validate_v959({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v959({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v959({}), [])


if __name__ == "__main__":
    unittest.main()
