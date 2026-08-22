import unittest
from tools.package.source_hash_provenance_v720 import validate_v720
class V720Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v720({"schema_version":720}),[])
 def test_schema(self):self.assertIn("schema_version must be 720",validate_v720({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v720({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v720({}),[])
if __name__=="__main__":unittest.main()
