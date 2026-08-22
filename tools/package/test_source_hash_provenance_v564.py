import unittest
from tools.package.source_hash_provenance_v564 import validate_v564
class V564Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v564({})))
 def test_schema(self):self.assertIn("schema_version must be 564",validate_v564({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v564({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v564({}),[])
if __name__=="__main__":unittest.main()
