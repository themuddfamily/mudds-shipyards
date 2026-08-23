import unittest
from tools.package.source_hash_provenance_v778 import validate_v778
class V778Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v778({"schema_version":778}),[])
 def test_schema(self):self.assertIn("schema_version must be 778",validate_v778({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v778({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v778({}),[])
if __name__=="__main__":unittest.main()
