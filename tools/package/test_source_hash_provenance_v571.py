import unittest
from tools.package.source_hash_provenance_v571 import validate_v571
class V571Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v571({})))
 def test_schema(self):self.assertIn("schema_version must be 571",validate_v571({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v571({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v571({}),[])
if __name__=="__main__":unittest.main()
