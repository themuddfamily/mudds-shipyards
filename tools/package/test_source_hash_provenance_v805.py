import unittest
from tools.package.source_hash_provenance_v805 import validate_v805
class V805Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v805({"schema_version":805}),[])
 def test_schema(self):self.assertIn("schema_version must be 805",validate_v805({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v805({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v805({}),[])
if __name__=="__main__":unittest.main()
