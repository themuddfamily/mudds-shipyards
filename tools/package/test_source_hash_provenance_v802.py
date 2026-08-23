import unittest
from tools.package.source_hash_provenance_v802 import validate_v802
class V802Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v802({"schema_version":802}),[])
 def test_schema(self):self.assertIn("schema_version must be 802",validate_v802({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v802({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v802({}),[])
if __name__=="__main__":unittest.main()
