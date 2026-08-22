import unittest
from tools.package.source_hash_provenance_v473 import validate_v473
class V473Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v473({})))
 def test_schema(self):self.assertIn("schema_version must be 473",validate_v473({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v473({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v473({}),[])
if __name__=="__main__":unittest.main()
