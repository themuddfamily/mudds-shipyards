import unittest
from tools.package.source_hash_provenance_v630 import validate_v630
class V630Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v630({"schema_version":630}),[])
 def test_schema(self):self.assertIn("schema_version must be 630",validate_v630({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v630({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v630({}),[])
if __name__=="__main__":unittest.main()
