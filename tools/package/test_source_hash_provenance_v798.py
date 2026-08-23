import unittest
from tools.package.source_hash_provenance_v798 import validate_v798
class V798Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v798({"schema_version":798}),[])
 def test_schema(self):self.assertIn("schema_version must be 798",validate_v798({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v798({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v798({}),[])
if __name__=="__main__":unittest.main()
