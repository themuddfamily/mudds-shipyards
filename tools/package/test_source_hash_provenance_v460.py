import unittest
from tools.package.source_hash_provenance_v460 import validate_v460
class V460Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v460({})))
 def test_schema(self):self.assertIn("schema_version must be 460",validate_v460({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v460({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v460({}),[])
if __name__=="__main__":unittest.main()
