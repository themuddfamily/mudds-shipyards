import unittest
from tools.package.source_hash_provenance_v766 import validate_v766
class V766Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v766({"schema_version":766}),[])
 def test_schema(self):self.assertIn("schema_version must be 766",validate_v766({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v766({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v766({}),[])
if __name__=="__main__":unittest.main()
