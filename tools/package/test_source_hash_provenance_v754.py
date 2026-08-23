import unittest
from tools.package.source_hash_provenance_v754 import validate_v754
class V754Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v754({"schema_version":754}),[])
 def test_schema(self):self.assertIn("schema_version must be 754",validate_v754({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v754({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v754({}),[])
if __name__=="__main__":unittest.main()
