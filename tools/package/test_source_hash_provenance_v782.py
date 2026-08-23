import unittest
from tools.package.source_hash_provenance_v782 import validate_v782
class V782Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v782({"schema_version":782}),[])
 def test_schema(self):self.assertIn("schema_version must be 782",validate_v782({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v782({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v782({}),[])
if __name__=="__main__":unittest.main()
