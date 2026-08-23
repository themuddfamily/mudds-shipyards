import unittest
from tools.package.source_hash_provenance_v801 import validate_v801
class V801Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v801({"schema_version":801}),[])
 def test_schema(self):self.assertIn("schema_version must be 801",validate_v801({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v801({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v801({}),[])
if __name__=="__main__":unittest.main()
