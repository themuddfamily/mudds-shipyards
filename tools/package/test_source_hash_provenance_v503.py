import unittest
from tools.package.source_hash_provenance_v503 import validate_v503
class V503Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v503({})))
 def test_schema(self):self.assertIn("schema_version must be 503",validate_v503({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v503({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v503({}),[])
if __name__=="__main__":unittest.main()
