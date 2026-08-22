import unittest
from tools.package.source_hash_provenance_v560 import validate_v560
class V560Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v560({})))
 def test_schema(self):self.assertIn("schema_version must be 560",validate_v560({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v560({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v560({}),[])
if __name__=="__main__":unittest.main()
