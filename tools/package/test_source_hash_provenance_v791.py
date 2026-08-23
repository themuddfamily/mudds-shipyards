import unittest
from tools.package.source_hash_provenance_v791 import validate_v791
class V791Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v791({"schema_version":791}),[])
 def test_schema(self):self.assertIn("schema_version must be 791",validate_v791({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v791({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v791({}),[])
if __name__=="__main__":unittest.main()
