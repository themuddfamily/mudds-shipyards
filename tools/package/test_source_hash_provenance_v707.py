import unittest
from tools.package.source_hash_provenance_v707 import validate_v707
class V707Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v707({"schema_version":707}),[])
 def test_schema(self):self.assertIn("schema_version must be 707",validate_v707({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v707({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v707({}),[])
if __name__=="__main__":unittest.main()
