import unittest
from tools.package.source_hash_provenance_v788 import validate_v788
class V788Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v788({"schema_version":788}),[])
 def test_schema(self):self.assertIn("schema_version must be 788",validate_v788({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v788({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v788({}),[])
if __name__=="__main__":unittest.main()
