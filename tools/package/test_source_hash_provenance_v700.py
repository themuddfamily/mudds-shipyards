import unittest
from tools.package.source_hash_provenance_v700 import validate_v700
class V700Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v700({"schema_version":700}),[])
 def test_schema(self):self.assertIn("schema_version must be 700",validate_v700({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v700({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v700({}),[])
if __name__=="__main__":unittest.main()
