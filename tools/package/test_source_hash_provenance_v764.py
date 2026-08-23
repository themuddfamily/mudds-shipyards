import unittest
from tools.package.source_hash_provenance_v764 import validate_v764
class V764Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v764({"schema_version":764}),[])
 def test_schema(self):self.assertIn("schema_version must be 764",validate_v764({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v764({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v764({}),[])
if __name__=="__main__":unittest.main()
