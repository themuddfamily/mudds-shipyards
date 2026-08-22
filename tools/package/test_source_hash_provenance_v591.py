import unittest
from tools.package.source_hash_provenance_v591 import validate_v591
class V591Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v591({"schema_version":591}),[])
 def test_schema(self):self.assertIn("schema_version must be 591",validate_v591({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v591({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v591({}),[])
if __name__=="__main__":unittest.main()
