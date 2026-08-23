import unittest
from tools.package.source_hash_provenance_v751 import validate_v751
class V751Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v751({"schema_version":751}),[])
 def test_schema(self):self.assertIn("schema_version must be 751",validate_v751({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v751({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v751({}),[])
if __name__=="__main__":unittest.main()
