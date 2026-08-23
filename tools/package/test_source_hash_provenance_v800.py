import unittest
from tools.package.source_hash_provenance_v800 import validate_v800
class V800Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v800({"schema_version":800}),[])
 def test_schema(self):self.assertIn("schema_version must be 800",validate_v800({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v800({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v800({}),[])
if __name__=="__main__":unittest.main()
