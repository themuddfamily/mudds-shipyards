import unittest
from tools.package.source_hash_provenance_v572 import validate_v572
class V572Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v572({})))
 def test_schema(self):self.assertIn("schema_version must be 572",validate_v572({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v572({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v572({}),[])
if __name__=="__main__":unittest.main()
