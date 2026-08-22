import unittest
from tools.package.source_hash_provenance_v746 import validate_v746
class V746Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v746({"schema_version":746}),[])
 def test_schema(self):self.assertIn("schema_version must be 746",validate_v746({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v746({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v746({}),[])
if __name__=="__main__":unittest.main()
