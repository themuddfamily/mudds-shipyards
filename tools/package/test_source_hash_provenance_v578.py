import unittest
from tools.package.source_hash_provenance_v578 import validate_v578
class V578Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v578({})))
 def test_schema(self):self.assertIn("schema_version must be 578",validate_v578({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v578({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v578({}),[])
if __name__=="__main__":unittest.main()
