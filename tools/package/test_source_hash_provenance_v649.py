import unittest
from tools.package.source_hash_provenance_v649 import validate_v649
class V649Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v649({"schema_version":649}),[])
 def test_schema(self):self.assertIn("schema_version must be 649",validate_v649({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v649({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v649({}),[])
if __name__=="__main__":unittest.main()
