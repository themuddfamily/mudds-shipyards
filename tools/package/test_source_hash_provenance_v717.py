import unittest
from tools.package.source_hash_provenance_v717 import validate_v717
class V717Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v717({"schema_version":717}),[])
 def test_schema(self):self.assertIn("schema_version must be 717",validate_v717({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v717({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v717({}),[])
if __name__=="__main__":unittest.main()
