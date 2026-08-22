import unittest
from tools.package.source_hash_provenance_v575 import validate_v575
class V575Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v575({})))
 def test_schema(self):self.assertIn("schema_version must be 575",validate_v575({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v575({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v575({}),[])
if __name__=="__main__":unittest.main()
