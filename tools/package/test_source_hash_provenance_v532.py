import unittest
from tools.package.source_hash_provenance_v532 import validate_v532
class V532Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v532({})))
 def test_schema(self):self.assertIn("schema_version must be 532",validate_v532({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v532({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v532({}),[])
if __name__=="__main__":unittest.main()
