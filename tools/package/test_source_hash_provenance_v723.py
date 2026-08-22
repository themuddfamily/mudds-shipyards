import unittest
from tools.package.source_hash_provenance_v723 import validate_v723
class V723Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v723({"schema_version":723}),[])
 def test_schema(self):self.assertIn("schema_version must be 723",validate_v723({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v723({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v723({}),[])
if __name__=="__main__":unittest.main()
