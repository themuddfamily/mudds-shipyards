import unittest
from tools.package.source_hash_provenance_v795 import validate_v795
class V795Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v795({"schema_version":795}),[])
 def test_schema(self):self.assertIn("schema_version must be 795",validate_v795({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v795({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v795({}),[])
if __name__=="__main__":unittest.main()
