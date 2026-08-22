import unittest
from tools.package.source_hash_provenance_v739 import validate_v739
class V739Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v739({"schema_version":739}),[])
 def test_schema(self):self.assertIn("schema_version must be 739",validate_v739({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v739({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v739({}),[])
if __name__=="__main__":unittest.main()
