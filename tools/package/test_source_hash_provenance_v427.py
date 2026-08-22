import unittest
from tools.package.source_hash_provenance_v427 import validate_v427
class V427Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v427({})))
 def test_schema(self):self.assertIn("schema_version must be 427",validate_v427({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v427({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v427({}),[])
if __name__=="__main__":unittest.main()
