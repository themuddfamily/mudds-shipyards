import unittest
from tools.package.source_hash_provenance_v470 import validate_v470
class V470Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v470({})))
 def test_schema(self):self.assertIn("schema_version must be 470",validate_v470({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v470({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v470({}),[])
if __name__=="__main__":unittest.main()
