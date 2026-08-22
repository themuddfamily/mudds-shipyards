import unittest
from tools.package.source_hash_provenance_v588 import validate_v588
class V588Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v588({"schema_version":588}),[])
 def test_schema(self):self.assertIn("schema_version must be 588",validate_v588({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v588({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v588({}),[])
if __name__=="__main__":unittest.main()
