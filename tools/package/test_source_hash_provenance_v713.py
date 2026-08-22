import unittest
from tools.package.source_hash_provenance_v713 import validate_v713
class V713Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v713({"schema_version":713}),[])
 def test_schema(self):self.assertIn("schema_version must be 713",validate_v713({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v713({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v713({}),[])
if __name__=="__main__":unittest.main()
