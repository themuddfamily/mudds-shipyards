import unittest
from tools.package.source_hash_provenance_v719 import validate_v719
class V719Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v719({"schema_version":719}),[])
 def test_schema(self):self.assertIn("schema_version must be 719",validate_v719({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v719({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v719({}),[])
if __name__=="__main__":unittest.main()
