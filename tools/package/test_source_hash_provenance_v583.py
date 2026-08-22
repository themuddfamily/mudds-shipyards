import unittest
from tools.package.source_hash_provenance_v583 import validate_v583
class V583Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v583({})))
 def test_schema(self):self.assertIn("schema_version must be 583",validate_v583({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v583({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v583({}),[])
if __name__=="__main__":unittest.main()
