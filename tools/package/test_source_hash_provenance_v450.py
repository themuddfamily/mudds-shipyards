import unittest
from tools.package.source_hash_provenance_v450 import validate_v450
class V450Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v450({})))
 def test_schema(self):self.assertIn("schema_version must be 450",validate_v450({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v450({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v450({}),[])
if __name__=="__main__":unittest.main()
