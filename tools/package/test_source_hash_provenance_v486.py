import unittest
from tools.package.source_hash_provenance_v486 import validate_v486
class V486Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v486({})))
 def test_schema(self):self.assertIn("schema_version must be 486",validate_v486({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v486({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v486({}),[])
if __name__=="__main__":unittest.main()
