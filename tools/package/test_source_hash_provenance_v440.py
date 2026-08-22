import unittest
from tools.package.source_hash_provenance_v440 import validate_v440
class V440Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v440({})))
 def test_schema(self):self.assertIn("schema_version must be 440",validate_v440({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v440({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v440({}),[])
if __name__=="__main__":unittest.main()
