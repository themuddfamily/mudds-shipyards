import unittest
from tools.package.source_hash_provenance_v506 import validate_v506
class V506Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v506({})))
 def test_schema(self):self.assertIn("schema_version must be 506",validate_v506({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v506({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v506({}),[])
if __name__=="__main__":unittest.main()
