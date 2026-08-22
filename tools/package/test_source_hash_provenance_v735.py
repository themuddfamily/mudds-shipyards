import unittest
from tools.package.source_hash_provenance_v735 import validate_v735
class V735Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v735({"schema_version":735}),[])
 def test_schema(self):self.assertIn("schema_version must be 735",validate_v735({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v735({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v735({}),[])
if __name__=="__main__":unittest.main()
