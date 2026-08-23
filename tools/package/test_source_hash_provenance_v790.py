import unittest
from tools.package.source_hash_provenance_v790 import validate_v790
class V790Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v790({"schema_version":790}),[])
 def test_schema(self):self.assertIn("schema_version must be 790",validate_v790({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v790({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v790({}),[])
if __name__=="__main__":unittest.main()
