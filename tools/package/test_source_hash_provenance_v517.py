import unittest
from tools.package.source_hash_provenance_v517 import validate_v517
class V517Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v517({})))
 def test_schema(self):self.assertIn("schema_version must be 517",validate_v517({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v517({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v517({}),[])
if __name__=="__main__":unittest.main()
