import unittest
from tools.package.source_hash_provenance_v701 import validate_v701
class V701Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v701({"schema_version":701}),[])
 def test_schema(self):self.assertIn("schema_version must be 701",validate_v701({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v701({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v701({}),[])
if __name__=="__main__":unittest.main()
