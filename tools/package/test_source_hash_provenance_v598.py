import unittest
from tools.package.source_hash_provenance_v598 import validate_v598
class V598Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v598({"schema_version":598}),[])
 def test_schema(self):self.assertIn("schema_version must be 598",validate_v598({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v598({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v598({}),[])
if __name__=="__main__":unittest.main()
