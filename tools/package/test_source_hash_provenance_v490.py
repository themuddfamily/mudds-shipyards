import unittest
from tools.package.source_hash_provenance_v490 import validate_v490
class V490Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v490({})))
 def test_schema(self):self.assertIn("schema_version must be 490",validate_v490({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v490({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v490({}),[])
if __name__=="__main__":unittest.main()
