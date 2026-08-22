import unittest
from tools.package.source_hash_provenance_v727 import validate_v727
class V727Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v727({"schema_version":727}),[])
 def test_schema(self):self.assertIn("schema_version must be 727",validate_v727({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v727({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v727({}),[])
if __name__=="__main__":unittest.main()
