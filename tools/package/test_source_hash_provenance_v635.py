import unittest
from tools.package.source_hash_provenance_v635 import validate_v635
class V635Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v635({"schema_version":635}),[])
 def test_schema(self):self.assertIn("schema_version must be 635",validate_v635({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v635({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v635({}),[])
if __name__=="__main__":unittest.main()
