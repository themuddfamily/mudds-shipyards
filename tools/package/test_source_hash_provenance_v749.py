import unittest
from tools.package.source_hash_provenance_v749 import validate_v749
class V749Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v749({"schema_version":749}),[])
 def test_schema(self):self.assertIn("schema_version must be 749",validate_v749({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v749({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v749({}),[])
if __name__=="__main__":unittest.main()
