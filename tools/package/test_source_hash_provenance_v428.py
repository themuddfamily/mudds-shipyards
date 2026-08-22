import unittest
from tools.package.source_hash_provenance_v428 import validate_v428
class V428Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v428({})))
 def test_schema(self):self.assertIn("schema_version must be 428",validate_v428({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v428({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v428({}),[])
if __name__=="__main__":unittest.main()
