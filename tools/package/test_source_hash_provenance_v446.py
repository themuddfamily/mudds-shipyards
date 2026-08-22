import unittest
from tools.package.source_hash_provenance_v446 import validate_v446
class V446Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v446({})))
 def test_schema(self):self.assertIn("schema_version must be 446",validate_v446({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v446({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v446({}),[])
if __name__=="__main__":unittest.main()
