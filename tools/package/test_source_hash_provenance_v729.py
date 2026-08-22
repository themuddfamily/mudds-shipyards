import unittest
from tools.package.source_hash_provenance_v729 import validate_v729
class V729Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v729({"schema_version":729}),[])
 def test_schema(self):self.assertIn("schema_version must be 729",validate_v729({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v729({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v729({}),[])
if __name__=="__main__":unittest.main()
