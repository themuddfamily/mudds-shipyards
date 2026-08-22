import unittest
from tools.package.source_hash_provenance_v645 import validate_v645
class V645Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v645({"schema_version":645}),[])
 def test_schema(self):self.assertIn("schema_version must be 645",validate_v645({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v645({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v645({}),[])
if __name__=="__main__":unittest.main()
