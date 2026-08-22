import unittest
from tools.package.source_hash_provenance_v736 import validate_v736
class V736Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v736({"schema_version":736}),[])
 def test_schema(self):self.assertIn("schema_version must be 736",validate_v736({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v736({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v736({}),[])
if __name__=="__main__":unittest.main()
