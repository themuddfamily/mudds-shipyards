import unittest
from tools.package.source_hash_provenance_v426 import validate_v426
class V426Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v426({})))
 def test_schema(self):self.assertIn("schema_version must be 426",validate_v426({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v426({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v426({}),[])
if __name__=="__main__":unittest.main()
