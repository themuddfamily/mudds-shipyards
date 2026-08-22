import unittest
from tools.package.source_hash_provenance_v734 import validate_v734
class V734Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v734({"schema_version":734}),[])
 def test_schema(self):self.assertIn("schema_version must be 734",validate_v734({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v734({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v734({}),[])
if __name__=="__main__":unittest.main()
