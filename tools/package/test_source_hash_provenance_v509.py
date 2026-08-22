import unittest
from tools.package.source_hash_provenance_v509 import validate_v509
class V509Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v509({})))
 def test_schema(self):self.assertIn("schema_version must be 509",validate_v509({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v509({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v509({}),[])
if __name__=="__main__":unittest.main()
