import unittest
from tools.package.source_hash_provenance_v620 import validate_v620
class V620Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v620({"schema_version":620}),[])
 def test_schema(self):self.assertIn("schema_version must be 620",validate_v620({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v620({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v620({}),[])
if __name__=="__main__":unittest.main()
