import unittest
from tools.package.source_hash_provenance_v436 import validate_v436
class V436Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v436({})))
 def test_schema(self):self.assertIn("schema_version must be 436",validate_v436({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v436({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v436({}),[])
if __name__=="__main__":unittest.main()
