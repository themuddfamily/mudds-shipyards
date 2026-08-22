import unittest
from tools.package.source_hash_provenance_v502 import validate_v502
class V502Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v502({})))
 def test_schema(self):self.assertIn("schema_version must be 502",validate_v502({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v502({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v502({}),[])
if __name__=="__main__":unittest.main()
