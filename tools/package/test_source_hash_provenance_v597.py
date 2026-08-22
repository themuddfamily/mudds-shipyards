import unittest
from tools.package.source_hash_provenance_v597 import validate_v597
class V597Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v597({"schema_version":597}),[])
 def test_schema(self):self.assertIn("schema_version must be 597",validate_v597({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v597({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v597({}),[])
if __name__=="__main__":unittest.main()
