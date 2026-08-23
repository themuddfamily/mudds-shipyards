import unittest
from tools.package.source_hash_provenance_v789 import validate_v789
class V789Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v789({"schema_version":789}),[])
 def test_schema(self):self.assertIn("schema_version must be 789",validate_v789({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v789({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v789({}),[])
if __name__=="__main__":unittest.main()
