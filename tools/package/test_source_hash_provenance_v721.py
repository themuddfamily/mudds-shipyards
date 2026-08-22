import unittest
from tools.package.source_hash_provenance_v721 import validate_v721
class V721Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v721({"schema_version":721}),[])
 def test_schema(self):self.assertIn("schema_version must be 721",validate_v721({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v721({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v721({}),[])
if __name__=="__main__":unittest.main()
