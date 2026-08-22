import unittest
from tools.package.source_hash_provenance_v566 import validate_v566
class V566Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v566({})))
 def test_schema(self):self.assertIn("schema_version must be 566",validate_v566({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v566({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v566({}),[])
if __name__=="__main__":unittest.main()
