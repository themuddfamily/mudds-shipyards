import unittest
from tools.package.source_hash_provenance_v627 import validate_v627
class V627Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v627({"schema_version":627}),[])
 def test_schema(self):self.assertIn("schema_version must be 627",validate_v627({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v627({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v627({}),[])
if __name__=="__main__":unittest.main()
