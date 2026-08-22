import unittest
from tools.package.source_hash_provenance_v461 import validate_v461
class V461Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v461({})))
 def test_schema(self):self.assertIn("schema_version must be 461",validate_v461({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v461({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v461({}),[])
if __name__=="__main__":unittest.main()
