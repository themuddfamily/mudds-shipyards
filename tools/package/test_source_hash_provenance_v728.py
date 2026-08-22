import unittest
from tools.package.source_hash_provenance_v728 import validate_v728
class V728Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v728({"schema_version":728}),[])
 def test_schema(self):self.assertIn("schema_version must be 728",validate_v728({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v728({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v728({}),[])
if __name__=="__main__":unittest.main()
