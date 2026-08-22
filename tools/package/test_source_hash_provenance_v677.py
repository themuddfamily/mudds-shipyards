import unittest
from tools.package.source_hash_provenance_v677 import validate_v677
class V677Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v677({"schema_version":677}),[])
 def test_schema(self):self.assertIn("schema_version must be 677",validate_v677({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v677({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v677({}),[])
if __name__=="__main__":unittest.main()
