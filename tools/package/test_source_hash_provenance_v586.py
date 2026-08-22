import unittest
from tools.package.source_hash_provenance_v586 import validate_v586
class V586Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v586({"schema_version":586}),[])
 def test_schema(self):self.assertIn("schema_version must be 586",validate_v586({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v586({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v586({}),[])
if __name__=="__main__":unittest.main()
