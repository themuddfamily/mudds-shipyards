import unittest
from tools.package.source_hash_provenance_v774 import validate_v774
class V774Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v774({"schema_version":774}),[])
 def test_schema(self):self.assertIn("schema_version must be 774",validate_v774({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v774({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v774({}),[])
if __name__=="__main__":unittest.main()
