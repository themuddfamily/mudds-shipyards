import unittest
from tools.package.source_hash_provenance_v796 import validate_v796
class V796Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v796({"schema_version":796}),[])
 def test_schema(self):self.assertIn("schema_version must be 796",validate_v796({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v796({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v796({}),[])
if __name__=="__main__":unittest.main()
