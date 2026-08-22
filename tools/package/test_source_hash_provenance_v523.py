import unittest
from tools.package.source_hash_provenance_v523 import validate_v523
class V523Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v523({})))
 def test_schema(self):self.assertIn("schema_version must be 523",validate_v523({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v523({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v523({}),[])
if __name__=="__main__":unittest.main()
