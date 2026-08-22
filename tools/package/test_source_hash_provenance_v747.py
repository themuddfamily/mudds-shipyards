import unittest
from tools.package.source_hash_provenance_v747 import validate_v747
class V747Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v747({"schema_version":747}),[])
 def test_schema(self):self.assertIn("schema_version must be 747",validate_v747({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v747({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v747({}),[])
if __name__=="__main__":unittest.main()
