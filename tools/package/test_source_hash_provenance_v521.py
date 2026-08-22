import unittest
from tools.package.source_hash_provenance_v521 import validate_v521
class V521Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v521({})))
 def test_schema(self):self.assertIn("schema_version must be 521",validate_v521({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v521({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v521({}),[])
if __name__=="__main__":unittest.main()
