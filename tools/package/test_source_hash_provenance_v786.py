import unittest
from tools.package.source_hash_provenance_v786 import validate_v786
class V786Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v786({"schema_version":786}),[])
 def test_schema(self):self.assertIn("schema_version must be 786",validate_v786({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v786({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v786({}),[])
if __name__=="__main__":unittest.main()
