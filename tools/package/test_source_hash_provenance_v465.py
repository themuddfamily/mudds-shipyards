import unittest
from tools.package.source_hash_provenance_v465 import validate_v465
class V465Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v465({})))
 def test_schema(self):self.assertIn("schema_version must be 465",validate_v465({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v465({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v465({}),[])
if __name__=="__main__":unittest.main()
