import unittest
from tools.package.source_hash_provenance_v592 import validate_v592
class V592Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v592({"schema_version":592}),[])
 def test_schema(self):self.assertIn("schema_version must be 592",validate_v592({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v592({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v592({}),[])
if __name__=="__main__":unittest.main()
