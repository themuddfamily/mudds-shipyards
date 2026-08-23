import unittest

from tools.package.source_hash_provenance_v953 import validate_v953


class V953Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v953({"schema_version": 953}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 953",
            validate_v953({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v953({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v953({}), [])


if __name__ == "__main__":
    unittest.main()
