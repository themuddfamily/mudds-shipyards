import unittest
from tools.package.source_hash_provenance_v513 import validate_v513
class V513Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v513({})))
 def test_schema(self):self.assertIn("schema_version must be 513",validate_v513({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v513({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v513({}),[])
if __name__=="__main__":unittest.main()
