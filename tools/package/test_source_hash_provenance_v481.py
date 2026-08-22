import unittest
from tools.package.source_hash_provenance_v481 import validate_v481
class V481Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v481({})))
 def test_schema(self):self.assertIn("schema_version must be 481",validate_v481({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v481({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v481({}),[])
if __name__=="__main__":unittest.main()
