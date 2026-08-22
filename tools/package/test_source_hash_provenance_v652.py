import unittest
from tools.package.source_hash_provenance_v652 import validate_v652
class V652Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v652({"schema_version":652}),[])
 def test_schema(self):self.assertIn("schema_version must be 652",validate_v652({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v652({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v652({}),[])
if __name__=="__main__":unittest.main()
