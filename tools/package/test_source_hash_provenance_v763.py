import unittest
from tools.package.source_hash_provenance_v763 import validate_v763
class V763Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v763({"schema_version":763}),[])
 def test_schema(self):self.assertIn("schema_version must be 763",validate_v763({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v763({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v763({}),[])
if __name__=="__main__":unittest.main()
