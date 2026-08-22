import unittest
from tools.package.source_hash_provenance_v637 import validate_v637
class V637Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v637({"schema_version":637}),[])
 def test_schema(self):self.assertIn("schema_version must be 637",validate_v637({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v637({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v637({}),[])
if __name__=="__main__":unittest.main()
