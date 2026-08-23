import unittest

from tools.package.source_hash_provenance_v878 import validate_v878


class V878Test(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_v878({"schema_version": 878}), [])

    def test_schema(self):
        self.assertIn(
            "schema_version must be 878",
            validate_v878({"schema_version": 423})[0],
        )

    def test_label(self):
        self.assertTrue(validate_v878({}, "x"))

    def test_missing_schema(self):
        self.assertNotEqual(validate_v878({}), [])


if __name__ == "__main__":
    unittest.main()
