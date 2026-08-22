import unittest
from tools.package.source_hash_provenance_v462 import validate_v462
class V462Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v462({})))
 def test_schema(self):self.assertIn("schema_version must be 462",validate_v462({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v462({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v462({}),[])
if __name__=="__main__":unittest.main()
