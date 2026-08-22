import unittest
from tools.package.source_hash_provenance_v563 import validate_v563
class V563Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v563({})))
 def test_schema(self):self.assertIn("schema_version must be 563",validate_v563({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v563({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v563({}),[])
if __name__=="__main__":unittest.main()
