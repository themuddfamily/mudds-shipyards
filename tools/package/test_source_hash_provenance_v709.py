import unittest
from tools.package.source_hash_provenance_v709 import validate_v709
class V709Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v709({"schema_version":709}),[])
 def test_schema(self):self.assertIn("schema_version must be 709",validate_v709({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v709({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v709({}),[])
if __name__=="__main__":unittest.main()
