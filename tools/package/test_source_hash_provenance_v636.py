import unittest
from tools.package.source_hash_provenance_v636 import validate_v636
class V636Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v636({"schema_version":636}),[])
 def test_schema(self):self.assertIn("schema_version must be 636",validate_v636({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v636({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v636({}),[])
if __name__=="__main__":unittest.main()
