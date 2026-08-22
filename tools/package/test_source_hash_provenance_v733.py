import unittest
from tools.package.source_hash_provenance_v733 import validate_v733
class V733Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v733({"schema_version":733}),[])
 def test_schema(self):self.assertIn("schema_version must be 733",validate_v733({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v733({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v733({}),[])
if __name__=="__main__":unittest.main()
