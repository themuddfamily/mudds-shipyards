import unittest
from tools.package.source_hash_provenance_v441 import validate_v441
class V441Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v441({})))
 def test_schema(self):self.assertIn("schema_version must be 441",validate_v441({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v441({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v441({}),[])
if __name__=="__main__":unittest.main()
