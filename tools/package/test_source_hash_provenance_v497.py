import unittest
from tools.package.source_hash_provenance_v497 import validate_v497
class V497Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v497({})))
 def test_schema(self):self.assertIn("schema_version must be 497",validate_v497({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v497({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v497({}),[])
if __name__=="__main__":unittest.main()
