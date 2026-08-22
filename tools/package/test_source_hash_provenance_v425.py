import unittest
from tools.package.source_hash_provenance_v424 import validate_v424
from tools.package.source_hash_provenance_v425 import validate_v425
class V425Test(unittest.TestCase):
 def test_valid(self):
  self.assertTrue(any("schema_version must be 425" in e for e in validate_v425({})))
 def test_schema(self):self.assertIn("schema_version must be 425",validate_v425({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v425({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v425({}),[])
if __name__=="__main__":unittest.main()
