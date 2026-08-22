import unittest
from tools.package.source_hash_provenance_v504 import validate_v504
class V504Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v504({})))
 def test_schema(self):self.assertIn("schema_version must be 504",validate_v504({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v504({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v504({}),[])
if __name__=="__main__":unittest.main()
